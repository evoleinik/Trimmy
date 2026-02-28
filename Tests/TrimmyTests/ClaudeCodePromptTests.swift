import Foundation
import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
@Suite
struct ClaudeCodePromptTests {
    private let cleaner = TextCleaner()

    // MARK: - Scenario A: Full decoration (❯ + rule + duplicate content)

    @Test
    func stripsFullDecoration() {
        let text = """
        ❯ /skill:cmd "some args"
        ──────────────────────
        /skill:cmd "some args"
          --flag value
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/skill:cmd \"some args\" --flag value")
    }

    @Test
    func flattensFullDecorationWithWrappedArgs() {
        let text = """
        ❯ /my-skill:run-task "Analyze the dataset
          for patterns and report
          findings" --max-iterations 10
        ────────────────────────────────────────
        /my-skill:run-task "Analyze the dataset
          for patterns and report
          findings" --max-iterations 10
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result ==
            "/my-skill:run-task \"Analyze the dataset for patterns and report findings\" --max-iterations 10")
    }

    // MARK: - Scenario B: Raw slash command (multi-line, no decoration)

    @Test
    func flattensRawSlashCommand() {
        let text = """
        /skill:cmd "args
          wrapped" --flag
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/skill:cmd \"args wrapped\" --flag")
    }

    // MARK: - Scenario A/C hybrid: short prompt with decoration

    @Test
    func stripsShortPromptWithDecoration() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/commit")
    }

    // MARK: - Scenario C: ❯ prefix only (single line)

    @Test
    func stripsPartialPromptPrefix() {
        let text = "❯ /commit"
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/commit")
    }

    // MARK: - Scenario E: Outer-quoted slash command

    @Test
    func stripsOuterQuotesAndUnescapes() {
        let text = #""/my-skill:run-task \"Analyze the data for anomalies\" --max-iterations=50""#
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == #"/my-skill:run-task "Analyze the data for anomalies" --max-iterations=50"#)
    }

    @Test
    func stripsOuterQuotesLongPrompt() {
        let text = #""/my-skill:run-task \"Run a full analysis on the dataset. Check for patterns and outliers. Verify all results against baseline. Continue iterating until confidence is high enough to report.\" --max-iterations=100""#
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result != nil)
        #expect(result?.hasPrefix("/my-skill:run-task \"Run a full") == true)
        #expect(result?.hasSuffix("--max-iterations=100") == true)
        #expect(result?.contains("\\\"") == false)
    }

    // MARK: - Scenario D: Terminal-wrapped text

    @Test
    func flattensTerminalWrappedText() {
        let text = """
        This is a long prompt that got
          wrapped by the terminal to the
          next line automatically
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "This is a long prompt that got wrapped by the terminal to the next line automatically")
    }

    // MARK: - Negative cases

    @Test
    func doesNotFlattenCode() {
        let text = """
        func hello() {
            print("world")
        }
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func doesNotFlattenLists() {
        let text = """
        - item one
        - item two
        - item three
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func doesNotFlattenMultiParagraph() {
        let text = """
        First paragraph that is
          long enough.

        Second paragraph here
          also wrapped.
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func doesNotStripPlainSingleLine() {
        let text = "just a single line of text"
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    // MARK: - Setting respect

    @Test
    func respectsDisabledSetting() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let result = cleaner.stripClaudeCodeDecoration(text, enabled: false)
        #expect(result == nil)
    }

    // MARK: - Full pipeline integration

    @Test
    func fullPipelineIntegration() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let config = TrimConfig(
            aggressiveness: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true,
            flattenClaudeCodePrompts: true)
        let result = cleaner.transform(text, config: config)
        #expect(result.wasTransformed)
        #expect(result.trimmed == "/commit")
    }

    @Test
    func pipelineDisabledSetting() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let config = TrimConfig(
            aggressiveness: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true,
            flattenClaudeCodePrompts: false)
        let result = cleaner.transform(text, config: config)
        // The ❯ and ─── won't be handled by Claude Code stripping,
        // but other pipeline steps may still transform it
        #expect(result.trimmed != "/commit" || !result.wasTransformed)
    }
}
