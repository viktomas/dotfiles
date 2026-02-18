#!/usr/bin/env node

import { execSync } from 'child_process';
import { exit } from 'process';

// Color output helpers
const colors = {
  RED: '\x1b[0;31m',
  GREEN: '\x1b[0;32m',
  YELLOW: '\x1b[1;33m',
  BLUE: '\x1b[0;34m',
  NC: '\x1b[0m' // No Color
};

function logError(message) {
  console.error(`${colors.RED}ERROR: ${message}${colors.NC}`);
}

function logInfo(message) {
  console.error(`${colors.BLUE}INFO: ${message}${colors.NC}`);
}

function logSuccess(message) {
  console.error(`${colors.GREEN}SUCCESS: ${message}${colors.NC}`);
}

// Parse MR URL to extract host, project path, and MR IID
function parseMrUrl(url) {
  // Remove protocol
  const cleaned = url.replace(/^.*:\/\//, '');
  
  // Extract host (everything before first /)
  const hostEnd = cleaned.indexOf('/');
  if (hostEnd === -1) {
    throw new Error('Invalid MR URL format. Expected: https://gitlab.com/org/project/-/merge_requests/123');
  }
  
  const host = cleaned.substring(0, hostEnd);
  const path = cleaned.substring(hostEnd + 1);
  
  // Extract project path (everything before /-/merge_requests/)
  const mrRegex = /(.*)\/\-\/merge_requests\/(\d+)/;
  const match = path.match(mrRegex);
  
  if (!match) {
    throw new Error('Invalid MR URL format. Expected: https://gitlab.com/org/project/-/merge_requests/123');
  }
  
  return {
    host: host,
    projectPath: match[1],
    mrIid: match[2]
  };
}

// Fetch discussions from GitLab API using glab
function fetchDiscussions(projectPath, mrIid) {
  logInfo(`Fetching discussions for MR !${mrIid} in ${projectPath}...`);
  
  // GraphQL query to fetch discussions
  const query = `query getMrDiscussions($projectPath: ID!, $iid: String!) {
  project(fullPath: $projectPath) {
    mergeRequest(iid: $iid) {
      discussions {
        nodes {
          id
          replyId
          createdAt
          resolved
          resolvable
          notes {
            nodes {
              id
              system
              author {
                name
                username
                avatarUrl
              }
              body
              bodyHtml
              createdAt
              position {
                diffRefs {
                  baseSha
                  headSha
                  startSha
                }
                filePath
                newPath
                oldPath
                positionType
                newLine
                oldLine
              }
            }
          }
        }
      }
    }
  }
}`;
  
  try {
    // Execute GraphQL query with glab using shell pipes to avoid quote escaping issues
    const result = execSync(
      `glab api graphql -f projectPath='${projectPath}' -f iid='${mrIid}' -f query='${query}'`,
      { 
        encoding: 'utf8',
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
        shell: '/bin/bash'
      }
    );
    
    return JSON.parse(result);
  } catch (error) {
    throw new Error(`Failed to fetch discussions: ${error.message}`);
  }
}

// Format a single note for output
function formatNote(note, discussionResolved) {
  const { author, createdAt, body, position } = note;
  const output = [];
  
  if (position) {
    // Diff note
    const filePath = position.newPath || position.oldPath;
    const newLine = position.newLine;
    const oldLine = position.oldLine;
    const headSha = position.diffRefs?.headSha;
    const baseSha = position.diffRefs?.baseSha;
    
    // Determine position type
    let positionType, lineInfo, commitSha;
    if (newLine !== null && oldLine === null) {
      positionType = 'ADDED';
      lineInfo = `Line ${newLine}`;
      commitSha = headSha;
    } else if (newLine === null && oldLine !== null) {
      positionType = 'REMOVED';
      lineInfo = `Line ${oldLine}`;
      commitSha = baseSha;
    } else {
      positionType = 'UNCHANGED';
      lineInfo = `Line ${newLine} (was ${oldLine})`;
      commitSha = headSha;
    }
    
    output.push('[DIFF NOTE]');
    output.push(`Author: @${author.username} (${author.name})`);
    output.push(`Created: ${createdAt}`);
    output.push(`File: ${filePath}`);
    output.push(`Position: ${lineInfo} (${positionType}) in commit ${commitSha?.substring(0, 7)}`);
    output.push(`Resolved: ${discussionResolved}`);
    output.push('');
    output.push(body);
    output.push('---');
  } else {
    // General note
    output.push('[GENERAL NOTE]');
    output.push(`Author: @${author.username} (${author.name})`);
    output.push(`Created: ${createdAt}`);
    output.push(`Resolved: ${discussionResolved}`);
    output.push('');
    output.push(body);
    output.push('---');
  }
  
  return output.join('\n');
}

// Check if required commands are available
function checkDependencies() {
  try {
    execSync('which glab', { stdio: 'ignore' });
  } catch {
    logError('glab CLI is not installed. Install it from: https://gitlab.com/gitlab-org/cli');
    exit(1);
  }
  
  try {
    execSync('which jq', { stdio: 'ignore' });
  } catch {
    logError('jq is not installed. Install it with: brew install jq');
    exit(1);
  }
}

// Get MR URL for current branch using glab
function getCurrentMrUrl() {
  logInfo('Fetching MR for current branch...');
  try {
    const result = execSync('glab mr view --output json', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    const mrData = JSON.parse(result);
    return mrData.web_url;
  } catch (error) {
    throw new Error(`Failed to get MR for current branch: ${error.message}. Make sure you're on a branch with an associated MR.`);
  }
}

// Main function
function main() {
  const args = process.argv.slice(2);
  
  // Parse arguments
  let mrUrl = null;
  let showAll = false;
  
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--all' || arg === '-a') {
      showAll = true;
    } else if (arg === '--url') {
      if (i + 1 >= args.length) {
        console.log('ERROR: --url requires a URL argument');
        exit(1);
      }
      mrUrl = args[i + 1];
      i++; // Skip next arg since we consumed it
    } else {
      console.log(`Unknown option: ${arg}`);
      exit(1);
    }
  }
  
  // Check dependencies
  checkDependencies();
  
  // If no URL provided, get it from current branch
  if (!mrUrl) {
    try {
      mrUrl = getCurrentMrUrl();
      logSuccess(`Found MR: ${mrUrl}`);
    } catch (error) {
      logError(error.message);
      console.log('');
      console.log('Usage: read_mr_notes.js [--all] [--url <MR_URL>]');
      console.log('');
      console.log('Options:');
      console.log('  --all, -a         Show all discussions including resolved ones (default: hide resolved)');
      console.log('  --url <MR_URL>    Specify MR URL (default: use current branch MR)');
      console.log('');
      console.log('Example (use current branch):');
      console.log('  read_mr_notes.js');
      console.log('  read_mr_notes.js --all');
      console.log('');
      console.log('Example (specify URL):');
      console.log('  read_mr_notes.js --url https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870');
      console.log('  read_mr_notes.js --all --url https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870');
      exit(1);
    }
  }
  
  // Check dependencies
  checkDependencies();
  
  try {
    // Parse MR URL
    const { host, projectPath, mrIid } = parseMrUrl(mrUrl);
    
    logInfo(`Host: ${host}`);
    logInfo(`Project: ${projectPath}`);
    logInfo(`MR IID: ${mrIid}`);
    
    // Fetch discussions
    const response = fetchDiscussions(projectPath, mrIid);
    
    // Check if query was successful
    if (response.errors) {
      logError('GraphQL query failed:');
      console.error(JSON.stringify(response.errors, null, 2));
      exit(1);
    }
    
    // Extract and format all notes
    const discussions = response.data?.project?.mergeRequest?.discussions?.nodes || [];
    
    if (discussions.length === 0) {
      logInfo('No discussions found for this MR');
      exit(0);
    }
    
    let noteCount = 0;
    let skippedResolved = 0;
    
    for (const discussion of discussions) {
      const notes = discussion.notes?.nodes || [];
      
      if (notes.length === 0) {
        continue;
      }
      
      // Skip resolved discussions unless --all is passed
      if (!showAll && discussion.resolved) {
        skippedResolved += notes.filter(n => !n.system).length;
        continue;
      }
      
      for (const note of notes) {
        // Skip system-generated notes
        if (note.system) {
          continue;
        }
        
        console.log(formatNote(note, discussion.resolved));
        console.log('');
        noteCount++;
      }
    }
    
    if (skippedResolved > 0) {
      logInfo(`Skipped ${skippedResolved} resolved note(s) (use --all to show)`);
    }
    logSuccess(`Found ${noteCount} note(s)`);
  } catch (error) {
    logError(error.message);
    exit(1);
  }
}

main();
