# Security Policy

## Supported versions

WardAxis is in pre-release development. Only the latest release on the App Store and TestFlight, and the `master` branch, receive security fixes. Lab builds are never distributed and are out of scope for fixes, but reports about them are welcome.

## Report a vulnerability

Do not open a public issue, discussion or pull request for a vulnerability.

1. Open the repository's **Security** tab.
2. Select **Report a vulnerability**.
3. Complete the form: summary, details, proof of concept and impact.

We acknowledge a report within 5 business days and send a status update at least every 14 days until it is resolved. We coordinate the disclosure date with you and credit you in the advisory unless you ask us not to.

## Scope

In scope: the App Store app and its extensions on macOS, iOS/iPadOS and tvOS, the signed policy protocol, IPC, the management API and the NanoMDM integration in this repository.

Out of scope: vulnerabilities in Apple operating systems or third-party services (report them to the vendor), attacks that need administrator or kernel privileges, and denial of service against test infrastructure.

Test only on devices and servers you own.
