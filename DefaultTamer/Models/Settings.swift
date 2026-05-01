//
//  Settings.swift
//  Default Tamer
//
//  App settings model
//

import Foundation
import AppKit

struct Settings: Codable {
    var enabled: Bool
    var fallbackBrowserId: String
    var chooserModifierKey: String // "option" by default
    var diagnosticsEnabled: Bool
    var launchAtLogin: Bool
    var telemetryEnabled: Bool? // nil = not asked, true = opt-in, false = opt-out
    var hasCreatedFirstRule: Bool
    /// When true, opens the browser chooser whenever a URL doesn't match any rule
    /// instead of silently routing to the fallback browser.
    var showChooserForUnmatched: Bool
    /// Default save-rule option pre-selected in the browser chooser for unmatched URLs.
    var defaultChooserSaveOption: SaveRuleOption
    /// User-defined browser order in the chooser (bundle IDs). Empty = system default order.
    var browserOrder: [String]

    init(
        enabled: Bool = true,
        fallbackBrowserId: String = BundleIdentifiers.safari,
        chooserModifierKey: String = "option",
        diagnosticsEnabled: Bool = false,
        launchAtLogin: Bool = false,
        telemetryEnabled: Bool? = nil,
        hasCreatedFirstRule: Bool = false,
        showChooserForUnmatched: Bool = true,
        defaultChooserSaveOption: SaveRuleOption = .byDomain,
        browserOrder: [String] = []
    ) {
        self.enabled = enabled
        self.fallbackBrowserId = fallbackBrowserId
        self.chooserModifierKey = chooserModifierKey
        self.diagnosticsEnabled = diagnosticsEnabled
        self.launchAtLogin = launchAtLogin
        self.telemetryEnabled = telemetryEnabled
        self.hasCreatedFirstRule = hasCreatedFirstRule
        self.showChooserForUnmatched = showChooserForUnmatched
        self.defaultChooserSaveOption = defaultChooserSaveOption
        self.browserOrder = browserOrder
    }

    // Custom decoder so older settings JSON (without `showChooserForUnmatched`) still loads,
    // defaulting the new field instead of throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.fallbackBrowserId = try c.decodeIfPresent(String.self, forKey: .fallbackBrowserId) ?? BundleIdentifiers.safari
        self.chooserModifierKey = try c.decodeIfPresent(String.self, forKey: .chooserModifierKey) ?? "option"
        self.diagnosticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled) ?? false
        self.launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.telemetryEnabled = try c.decodeIfPresent(Bool.self, forKey: .telemetryEnabled)
        self.hasCreatedFirstRule = try c.decodeIfPresent(Bool.self, forKey: .hasCreatedFirstRule) ?? false
        self.showChooserForUnmatched = try c.decodeIfPresent(Bool.self, forKey: .showChooserForUnmatched) ?? true
        self.defaultChooserSaveOption = try c.decodeIfPresent(SaveRuleOption.self, forKey: .defaultChooserSaveOption) ?? .byDomain
        self.browserOrder = try c.decodeIfPresent([String].self, forKey: .browserOrder) ?? []
    }

    static let `default` = Settings()
}

// MARK: - Modifier Key Helpers

extension Settings {
    /// Maps the stored `chooserModifierKey` string to the corresponding
    /// `NSEvent.ModifierFlags` value used by the router.
    var chooserModifierFlags: NSEvent.ModifierFlags {
        switch chooserModifierKey.lowercased() {
        case "command":  return .command
        case "shift":    return .shift
        case "control":  return .control
        case "option":   return .option
        default:         return .option
        }
    }
}
