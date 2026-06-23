import { getBlockField, getScalarField, readRequiredTextFile } from "./markdown.js";

import type { UserBrInput } from "../types/index.js";

export function readUserBrInput(filePath: string): UserBrInput {
  const content = readRequiredTextFile(filePath);
  return {
    path: filePath,
    content,
    capturedAt: getScalarField(content, "captured_at"),
    jiraTicket: getScalarField(content, "jira_ticket"),
    featureId: getScalarField(content, "feature_id"),
    featureTitle: getScalarField(content, "feature_title"),
    epicStorySourceFile: getScalarField(content, "epic_story_source_file"),
    epicOrStory: getBlockField(content, "epic_or_story"),
    requestSummary: getScalarField(content, "request_summary"),
    additionalBusinessContext: getScalarField(content, "additional_business_context")
  };
}

export function capturedUserInputHasStoryContent(content: string): boolean {
  return getBlockField(content, "epic_or_story").split(/\r?\n/).some((line) => line.trim() !== "");
}
