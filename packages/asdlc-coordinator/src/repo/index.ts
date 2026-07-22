export { collectReadyRepoPaths } from "./collect-ready-paths.js";
export { checkRepoBranchState, syncRepoToDefaultBranch } from "./sync-repo.js";
export { listCommittedSiblingFeatures } from "./list-committed-sibling-features.js";
export { computeCrossClassPeerTrigger } from "./cross-class-peer-trigger.js";
export { attachClassRepo, validateClassRecordCoherence } from "./attach.js";
export type { AttachResult } from "./attach.js";
export type { ClassRepoEntry } from "./collect-ready-paths.js";
export type { RepoStateResult, SyncResult } from "./sync-repo.js";
export type { CrossClassPeerTrigger } from "./cross-class-peer-trigger.js";
