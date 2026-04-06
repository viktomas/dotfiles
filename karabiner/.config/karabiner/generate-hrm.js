#!/usr/bin/env node
// Generate Home Row Mods and Symbol Layer for Karabiner-Elements
//
// Usage: node generate-hrm.js [--apply]
//
// HRM Mappings:
//   Left hand:  a=alt, s=cmd, d=shift, f=ctrl
//   Right hand: j=ctrl, k=shift, l=cmd, ;=alt
//
// Symbol Layer (hold g or h to activate):
//   Left:  !@[]|  #$()` %^{}~
//   Right: ↑789*  ↓456+ &123/
//   right_command → 0
//
// Layer uses fn as the modifier (auto-releases on key up, no variable needed).
// See karabiner.md for detailed explanation.

const fs = require("fs");
const path = require("path");

const KARABINER_CONFIG = path.join(
  process.env.HOME,
  ".config/karabiner/karabiner.json"
);

// ── HRM Definitions ──────────────────────────────────────────────

const LEFT_MODS = [
  { key: "a", modifier: "left_option", label: "option" },
  { key: "s", modifier: "left_command", label: "command" },
  { key: "d", modifier: "left_shift", label: "shift" },
  { key: "f", modifier: "left_control", label: "control" },
];

const RIGHT_MODS = [
  { key: "j", modifier: "right_control", label: "control" },
  { key: "k", modifier: "right_shift", label: "shift" },
  { key: "l", modifier: "right_command", label: "command" },
  { key: "semicolon", modifier: "right_option", label: "option" },
];

// ── Symbol Layer Definitions ─────────────────────────────────────

// fn is used as the layer modifier — Karabiner auto-releases it on key up
const LAYER_MODIFIER = "fn";

// Helper to define shifted key output
const shift = (key_code) => ({ key_code, modifiers: ["left_shift"] });
const plain = (key_code) => ({ key_code });

// Layer mappings: physical key → output when layer is active
// Left hand
const LAYER_LEFT = [
  // Top row:    !        @        [                ]                |
  { from: "q", to: shift("1") },
  { from: "w", to: shift("2") },
  { from: "e", to: plain("open_bracket") },
  { from: "r", to: plain("close_bracket") },
  { from: "t", to: shift("backslash") },
  // Home row:   #        $        (                )                `
  { from: "a", to: shift("3") },
  { from: "s", to: shift("4") },
  { from: "d", to: shift("9") },
  { from: "f", to: shift("0") },
  { from: "g", to: plain("grave_accent_and_tilde") },
  // Bottom row: %        ^        {                }                ~
  { from: "z", to: shift("5") },
  { from: "x", to: shift("6") },
  { from: "c", to: shift("open_bracket") },
  { from: "v", to: shift("close_bracket") },
  { from: "b", to: shift("grave_accent_and_tilde") },
];

// Right hand
const LAYER_RIGHT = [
  // Top row:    ↑        7        8        9        *
  { from: "y", to: plain("up_arrow") },
  { from: "u", to: plain("7") },
  { from: "i", to: plain("8") },
  { from: "o", to: plain("9") },
  { from: "p", to: shift("8") },
  // Home row:   ↓        4        5        6        +
  { from: "h", to: plain("down_arrow") },
  { from: "j", to: plain("4") },
  { from: "k", to: plain("5") },
  { from: "l", to: plain("6") },
  { from: "semicolon", to: shift("equal_sign") },
  // Bottom row: &        1        2        3        / (no-op, skip)
  { from: "n", to: shift("7") },
  { from: "m", to: plain("1") },
  { from: "comma", to: plain("2") },
  { from: "period", to: plain("3") },
  // Extra row: 0 on right_command
  { from: "right_command", to: plain("0") },
];

// ── HRM Rule Generation ─────────────────────────────────────────

function keyDisplay(key) {
  return key === "semicolon" ? ";" : key;
}

function singleKeyManipulator(entry) {
  return {
    type: "basic",
    from: {
      key_code: entry.key,
      modifiers: { optional: ["any"] },
    },
    to_if_alone: [{ halt: true, key_code: entry.key }],
    to_if_held_down: [{ halt: true, key_code: entry.modifier }],
    to_delayed_action: {
      to_if_canceled: [{ key_code: entry.key }],
      to_if_invoked: [{ key_code: "vk_none" }],
    },
  };
}

function generateHRMRules() {
  const rules = [];
  for (const [hand, mods] of [
    ["left", LEFT_MODS],
    ["right", RIGHT_MODS],
  ]) {
    const keys = mods.map((m) => keyDisplay(m.key)).join(",");
    const modLabels = mods.map((m) => m.label).join(",");
    rules.push({
      description: `HRM ${hand} (${keys}) - ${modLabels}`,
      manipulators: mods.map((entry) => singleKeyManipulator(entry)),
    });
  }
  return rules;
}

// ── Symbol Layer Rule Generation ─────────────────────────────────

// Layer triggers use the same HRM pattern: tap = letter, hold = fn modifier.
// fn auto-releases when the key is released (standard Karabiner modifier behavior).
function layerTriggerManipulator(key) {
  return {
    type: "basic",
    from: {
      key_code: key,
      modifiers: { optional: ["any"] },
    },
    to_if_alone: [{ halt: true, key_code: key }],
    to_if_held_down: [{ halt: true, key_code: LAYER_MODIFIER }],
    to_delayed_action: {
      to_if_canceled: [{ key_code: key }],
      to_if_invoked: [{ key_code: "vk_none" }],
    },
  };
}

// Layer mappings require fn in mandatory modifiers.
// When fn is held (via g/h trigger), the mapping fires.
// fn is stripped from output (mandatory modifiers are consumed).
function layerMappingManipulator(mapping) {
  const to = { key_code: mapping.to.key_code };
  if (mapping.to.modifiers) {
    to.modifiers = mapping.to.modifiers;
  }
  return {
    type: "basic",
    from: {
      key_code: mapping.from,
      modifiers: {
        mandatory: [LAYER_MODIFIER],
        optional: ["any"],
      },
    },
    to: [to],
  };
}

function generateLayerRules() {
  const rules = [];

  // Layer key mappings (must come before HRM so they take priority when active)
  const leftManipulators = LAYER_LEFT.map(layerMappingManipulator);
  const rightManipulators = LAYER_RIGHT.map(layerMappingManipulator);

  rules.push({
    description: "SYM layer left (!@[]| #$()` %^{}~)",
    manipulators: leftManipulators,
  });

  rules.push({
    description: "SYM layer right (↑789* ↓456+ &123/ 0)",
    manipulators: rightManipulators,
  });

  // Layer triggers (g and h)
  rules.push({
    description: "SYM layer triggers (g,h)",
    manipulators: [
      layerTriggerManipulator("g"),
      layerTriggerManipulator("h"),
    ],
  });

  return rules;
}

// ── Parameters ───────────────────────────────────────────────────

const HRM_PARAMETERS = {
  "basic.to_if_alone_timeout_milliseconds": 400,
  "basic.to_if_held_down_threshold_milliseconds": 150,
  "basic.simultaneous_threshold_milliseconds": 50,
};

// ── Apply / Print ────────────────────────────────────────────────

const GENERATED_RE = /^(HRM |SYM )/;

function applyToConfig() {
  const config = JSON.parse(fs.readFileSync(KARABINER_CONFIG, "utf8"));
  const profile = config.profiles.find((p) => p.selected);

  if (!profile) {
    console.error("No selected profile found!");
    process.exit(1);
  }

  if (!profile.complex_modifications) {
    profile.complex_modifications = { rules: [], parameters: {} };
  }

  // Remove existing generated rules
  profile.complex_modifications.rules =
    profile.complex_modifications.rules.filter(
      (r) => !GENERATED_RE.test(r.description)
    );

  // Add new rules: layer mappings → layer triggers → HRM
  const layerRules = generateLayerRules();
  const hrmRules = generateHRMRules();
  const allRules = [...layerRules, ...hrmRules];

  profile.complex_modifications.rules.push(...allRules);

  // Set parameters
  profile.complex_modifications.parameters = {
    ...profile.complex_modifications.parameters,
    ...HRM_PARAMETERS,
  };

  fs.writeFileSync(KARABINER_CONFIG, JSON.stringify(config, null, 2) + "\n");

  const totalManipulators = allRules.reduce(
    (s, r) => s + r.manipulators.length,
    0
  );
  console.log(
    `Applied ${allRules.length} rules (${totalManipulators} manipulators) to profile "${profile.name}"`
  );
  console.log(
    `  Layer rules: ${layerRules.length} (${layerRules.reduce((s, r) => s + r.manipulators.length, 0)} manipulators)`
  );
  console.log(
    `  HRM rules: ${hrmRules.length} (${hrmRules.reduce((s, r) => s + r.manipulators.length, 0)} manipulators)`
  );
  console.log("Parameters:", JSON.stringify(HRM_PARAMETERS, null, 2));
}

function printRules() {
  const layerRules = generateLayerRules();
  const hrmRules = generateHRMRules();
  console.log(
    JSON.stringify(
      { rules: [...layerRules, ...hrmRules], parameters: HRM_PARAMETERS },
      null,
      2
    )
  );
}

// Main
if (process.argv.includes("--apply")) {
  applyToConfig();
} else {
  printRules();
  console.log("\nRun with --apply to write to karabiner.json");
}
