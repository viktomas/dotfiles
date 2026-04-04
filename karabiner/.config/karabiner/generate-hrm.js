#!/usr/bin/env node
// Generate Home Row Mods for Karabiner-Elements
//
// Usage: node generate-hrm.js [--apply]
//
// Mappings:
//   Left hand:  a=alt, s=cmd, d=shift, f=ctrl
//   Right hand: j=ctrl, k=shift, l=cmd, ;=alt
//
// Multi-modifier: hold first key until modifier activates, then hold second key.
// See karabiner.md for detailed explanation.

const fs = require("fs");
const path = require("path");

const KARABINER_CONFIG = path.join(
  process.env.HOME,
  ".config/karabiner/karabiner.json"
);

// Define the home row mod keys
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

// For display in key_code (semicolon needs special handling)
function keyDisplay(key) {
  return key === "semicolon" ? ";" : key;
}

// Generate a single-key manipulator (hold = modifier, tap = key)
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

// Build the complete rule
function generateHRMRules() {
  const rules = [];

  for (const [hand, mods] of [
    ["left", LEFT_MODS],
    ["right", RIGHT_MODS],
  ]) {
    const keys = mods.map((m) => keyDisplay(m.key)).join(",");
    const modLabels = mods.map((m) => m.label).join(",");

    const manipulators = mods.map((entry) => singleKeyManipulator(entry));

    rules.push({
      description: `HRM ${hand} (${keys}) - ${modLabels}`,
      manipulators,
    });
  }

  return rules;
}

// Parameters to set
const HRM_PARAMETERS = {
  "basic.to_if_alone_timeout_milliseconds": 400,
  "basic.to_if_held_down_threshold_milliseconds": 150,
  "basic.simultaneous_threshold_milliseconds": 50,
};

const RULE_PREFIX = "HRM ";

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

  // Remove existing HRM rules
  profile.complex_modifications.rules =
    profile.complex_modifications.rules.filter(
      (r) => !r.description?.startsWith(RULE_PREFIX)
    );

  // Add new HRM rules
  const hrmRules = generateHRMRules();
  profile.complex_modifications.rules.push(...hrmRules);

  // Set parameters
  profile.complex_modifications.parameters = {
    ...profile.complex_modifications.parameters,
    ...HRM_PARAMETERS,
  };

  fs.writeFileSync(KARABINER_CONFIG, JSON.stringify(config, null, 2) + "\n");
  console.log(
    `Applied HRM rules to profile "${profile.name}" (${hrmRules.length} rules, ${hrmRules.reduce((s, r) => s + r.manipulators.length, 0)} manipulators)`
  );
  console.log("Parameters set:", JSON.stringify(HRM_PARAMETERS, null, 2));
}

function printRules() {
  const rules = generateHRMRules();
  console.log(JSON.stringify({ rules, parameters: HRM_PARAMETERS }, null, 2));
}

// Main
if (process.argv.includes("--apply")) {
  applyToConfig();
} else {
  printRules();
  console.log("\nRun with --apply to write to karabiner.json");
}
