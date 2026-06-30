import * as assert from 'assert';
import { ASDLC_WATCH_PATTERNS } from '../../dashboard/fileWatchers';

suite('ASDLC file watchers', () => {
  test('watches metadata, project state, and feature artifacts', () => {
    assert.deepStrictEqual(ASDLC_WATCH_PATTERNS, [
      'asdlc_metadata.yaml',
      'projects/*/init_progress_definition.yaml',
      'projects/*/step_state.md',
      'projects/*/step_state_*.md',
      'projects/*/*/feature_br_summary.md',
      'projects/*/*/user_br_input.md',
      'projects/*/*/feature_design.md',
      'projects/*/*/step_plan.md',
      'projects/*/*/step_state.md'
    ]);
  });
});
