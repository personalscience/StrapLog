/// A page the guide's navigation stack can push. One value type, so links on any page resolve
/// through the stack's single `navigationDestination`.
enum HelpRoute: Hashable {
    case chapter(title: String)
    case acknowledgements
    case license(Acknowledgement)
}
