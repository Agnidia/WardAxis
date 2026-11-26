//
//  BuildConditions.swift
//
//  Created on 26.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

// Previews use DEBUG-only mocks and factories such as `AppContainer.preview()`,
// so PREVIEW_DEBUG must be defined exactly when DEBUG is (Configurations/debug.xcconfig).
#if (DEBUG && !PREVIEW_DEBUG) || (PREVIEW_DEBUG && !DEBUG)
#error("PREVIEW_DEBUG must be defined exactly when DEBUG is; see Configurations/debug.xcconfig")
#endif
