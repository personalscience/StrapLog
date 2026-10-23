import Foundation

/// A page the guide's navigation stack can push. One value type, so links on any page resolve
/// through the stack's single `navigationDestination`.
enum HelpRoute: Hashable {
    case chapter(title: String)
    case acknowledgements
    case license(Acknowledgement)

    /// The one place the app links out: the web guide's *Analyze it* section on the skills.
    static let analyzeURL = URL(string: "https://personalscience.com/docs/straplog/#analyze")!

    /// What Claude Code needs to install the skills, as the Help footer copies it.
    static let installCommands = """
        /plugin marketplace add personalscience/straplog-skills
        /plugin install straplog-skills@personalscience
        """
}
