//
//  MailExtension.swift
//
//  Created on 25.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import MailKit

/// Packaging shell for the MailKit extension.
///
/// Trust boundary: message content and recipients in Mail. The shell declares no
/// capability and returns no handler, so Mail passes it no message data.
final class MailExtension: NSObject, MEExtension {}
