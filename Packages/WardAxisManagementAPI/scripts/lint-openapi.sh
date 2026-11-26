#!/bin/bash
# Lints the WardAxisManagementAPI OpenAPI spec with vacuum, then reports breaking changes
# against the base spec with oasdiff. Breaking changes fail the script only from
# the freeze date on; before it they are reported and the script still passes.
#
# Exit codes: 0 pass, 1 lint error or enforced breaking-change failure,
# 2 usage error, 3 required tool missing outside CI.
set -euo pipefail

# git show on the client copy returns the symlink text, so the base is always
# read from the canonical file.
readonly CANONICAL_SPEC_PATH="Packages/WardAxisManagementAPI/Sources/WardAxisAPIServer/openapi.yaml"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="$(cd "$script_dir/.." && pwd)"

spec="$package_dir/Sources/WardAxisAPIServer/openapi.yaml"
base_spec=""
today="$(date -u +%Y-%m-%d)"
freeze_date="2027-01-15"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--spec PATH] [--base-spec PATH] [--today YYYY-MM-DD] [--freeze-date YYYY-MM-DD]

  --spec PATH          Spec to lint and compare (default: the canonical spec).
  --base-spec PATH     Base spec for the breaking-change check. Without it, a pull
                       request build reads the spec from CI_PULL_REQUEST_TARGET_BRANCH.
  --today DATE         Current date in UTC (default: today).
  --freeze-date DATE   First day on which breaking changes fail (default: $freeze_date).
USAGE
}

usage_error() {
    echo "lint-openapi: $1" >&2
    usage >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --spec | --base-spec | --today | --freeze-date)
            [ $# -ge 2 ] || usage_error "$1 needs a value"
            case "$1" in
                --spec) spec="$2" ;;
                --base-spec) base_spec="$2" ;;
                --today) today="$2" ;;
                --freeze-date) freeze_date="$2" ;;
            esac
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) usage_error "unknown argument: $1" ;;
    esac
done

date_pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
[[ "$today" =~ $date_pattern ]] || usage_error "--today must be YYYY-MM-DD, got '$today'"
[[ "$freeze_date" =~ $date_pattern ]] || usage_error "--freeze-date must be YYYY-MM-DD, got '$freeze_date'"
[ -f "$spec" ] || usage_error "spec not found: $spec"
if [ -n "$base_spec" ] && [ ! -f "$base_spec" ]; then
    usage_error "base spec not found: $base_spec"
fi

# Archive and branch workflows sign and ship builds, so third-party lint tools
# never install or run there; only pull request builds lint the spec.
if [ -n "${CI:-}" ] && [ -z "${CI_PULL_REQUEST_NUMBER:-}" ] && [ -z "${CI_PULL_REQUEST_TARGET_BRANCH:-}" ]; then
    echo "notice: CI build that is not a pull request; skipped the spec lint."
    exit 0
fi

# The workflow environment can hold CI secrets, so the third-party tools get
# only what they need to run.
run_tool() {
    env -i PATH="$PATH" HOME="${HOME:-}" TMPDIR="${TMPDIR:-/tmp}" "$@"
}

missing_tools=()
for tool in vacuum oasdiff; do
    command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
# Bash 3.2 treats "${missing_tools[@]}" of an empty array as unbound under
# set -u, so the array is expanded only after the length check.
if [ ${#missing_tools[@]} -gt 0 ]; then
    if [ -n "${CI:-}" ]; then
        echo "Installing from Homebrew: ${missing_tools[*]}"
        HOMEBREW_NO_AUTO_UPDATE=1 brew install "${missing_tools[@]}"
    else
        echo "lint-openapi: missing tools: ${missing_tools[*]}" >&2
        echo "Install them with: brew install ${missing_tools[*]}" >&2
        exit 3
    fi
fi
echo "vacuum $(run_tool vacuum version 2>&1 | head -n 1)"
run_tool oasdiff --version

echo "==> vacuum lint $spec"
if ! run_tool vacuum lint --no-banner --no-style --details --fail-severity error "$spec"; then
    echo "lint-openapi: vacuum found errors in $spec" >&2
    exit 1
fi

# ISO dates sort lexically, which avoids the GNU and BSD date differences.
enforce=false
if ! [[ "$today" < "$freeze_date" ]]; then
    enforce=true
fi

# From the freeze date a check that cannot run fails closed, so the gate is
# never skipped without anyone noticing.
gate_failure() {
    if [ "$enforce" = true ]; then
        echo "lint-openapi: $1 (breaking changes are enforced since $freeze_date)" >&2
        exit 1
    fi
    echo "warning: $1 (report only until $freeze_date)" >&2
    exit 0
}

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

if [ -z "$base_spec" ]; then
    target_branch="${CI_PULL_REQUEST_TARGET_BRANCH:-}"
    if [ -z "$target_branch" ]; then
        echo "notice: not a pull request build and no --base-spec given; skipped the breaking-change check."
        exit 0
    fi
    case "$target_branch" in
        -*) gate_failure "CI_PULL_REQUEST_TARGET_BRANCH must not start with '-'" ;;
    esac
    repo_root="$(git -C "$package_dir" rev-parse --show-toplevel 2>/dev/null)" ||
        gate_failure "$package_dir is not inside a git repository"
    # --depth on a full clone writes a shallow graft into the shared .git and
    # cuts the history of every worktree, so it is used only on a clone that
    # is already shallow (the Xcode Cloud case).
    fetch_args=(fetch --quiet)
    if [ "$(git -C "$repo_root" rev-parse --is-shallow-repository)" = true ]; then
        fetch_args+=(--depth=1)
    fi
    git -C "$repo_root" "${fetch_args[@]}" origin "$target_branch" ||
        gate_failure "could not fetch origin/$target_branch"
    if ! git -C "$repo_root" cat-file -e "FETCH_HEAD:$CANONICAL_SPEC_PATH" 2>/dev/null; then
        # Only a fetched commit that lacks the file means "no spec yet"; any
        # other git failure goes through the gate, so it fails closed after
        # the freeze.
        git -C "$repo_root" rev-parse --verify --quiet "FETCH_HEAD^{commit}" >/dev/null ||
            gate_failure "could not resolve the fetched origin/$target_branch"
        echo "notice: origin/$target_branch has no $CANONICAL_SPEC_PATH; skipped the breaking-change check."
        exit 0
    fi
    git -C "$repo_root" show "FETCH_HEAD:$CANONICAL_SPEC_PATH" >"$work_dir/base-openapi.yaml" ||
        gate_failure "could not read $CANONICAL_SPEC_PATH from origin/$target_branch"
    base_spec="$work_dir/base-openapi.yaml"
fi

oasdiff_args=(breaking "$base_spec" "$spec")
if [ "$enforce" = true ]; then
    oasdiff_args+=(--fail-on ERR)
fi
if [ -f "$package_dir/oasdiff-ignore.txt" ]; then
    oasdiff_args+=(--err-ignore "$package_dir/oasdiff-ignore.txt")
fi

echo "==> oasdiff ${oasdiff_args[*]} (enforce=$enforce, today=$today, freeze=$freeze_date)"
if ! run_tool oasdiff "${oasdiff_args[@]}"; then
    gate_failure "oasdiff reported breaking changes or failed"
fi
echo "lint-openapi: passed"
