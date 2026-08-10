pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Search field adapted from end-4's overview search bar.
Item {
  id: root

  implicitHeight: 48
  property alias searchInput: searchInput
  property string searchingText: searchInput.text
  signal accepted()
  signal escapePressed()
  signal navigateLeft()
  signal navigateRight()
  signal navigateUp()
  signal navigateDown()

  function forceFocus() { searchInput.forceActiveFocus() }

  enum SearchPrefixType {
    Action, App, Clipboard, Emojis, Math, ShellCommand, WebSearch, DefaultSearch
  }

  property var searchPrefixType: {
    if (root.searchingText.startsWith(Config.options.search.prefix.action)) return Search.SearchPrefixType.Action
    if (root.searchingText.startsWith(Config.options.search.prefix.app)) return Search.SearchPrefixType.App
    if (root.searchingText.startsWith(Config.options.search.prefix.clipboard)) return Search.SearchPrefixType.Clipboard
    if (root.searchingText.startsWith(Config.options.search.prefix.emojis)) return Search.SearchPrefixType.Emojis
    if (root.searchingText.startsWith(Config.options.search.prefix.math)) return Search.SearchPrefixType.Math
    if (root.searchingText.startsWith(Config.options.search.prefix.shellCommand)) return Search.SearchPrefixType.ShellCommand
    if (root.searchingText.startsWith(Config.options.search.prefix.webSearch)) return Search.SearchPrefixType.WebSearch
    return Search.SearchPrefixType.DefaultSearch
  }

  ToolbarTextField {
    id: searchInput
    anchors.fill: parent
    leftPadding: 58
    rightPadding: 18
    focus: GlobalStates.searchOpen
    font.pixelSize: Appearance.font.pixelSize.small
    placeholderText: Translation.tr("Search, calculate or run")

    onAccepted: root.accepted()
    Keys.onEscapePressed: root.escapePressed()
    Keys.onLeftPressed: root.navigateLeft()
    Keys.onRightPressed: root.navigateRight()
    Keys.onUpPressed: root.navigateUp()
    Keys.onDownPressed: root.navigateDown()
  }

  MaterialShapeWrappedMaterialSymbol {
    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
    iconSize: Appearance.font.pixelSize.huge
    shape: switch (root.searchPrefixType) {
      case Search.SearchPrefixType.Action: return MaterialShape.Shape.Pill
      case Search.SearchPrefixType.App: return MaterialShape.Shape.Clover4Leaf
      case Search.SearchPrefixType.Clipboard: return MaterialShape.Shape.Gem
      case Search.SearchPrefixType.Emojis: return MaterialShape.Shape.Sunny
      case Search.SearchPrefixType.Math: return MaterialShape.Shape.PuffyDiamond
      case Search.SearchPrefixType.ShellCommand: return MaterialShape.Shape.PixelCircle
      case Search.SearchPrefixType.WebSearch: return MaterialShape.Shape.SoftBurst
      default: return MaterialShape.Shape.Cookie7Sided
    }
    text: switch (root.searchPrefixType) {
      case Search.SearchPrefixType.Action: return "settings_suggest"
      case Search.SearchPrefixType.App: return "apps"
      case Search.SearchPrefixType.Clipboard: return "content_paste_search"
      case Search.SearchPrefixType.Emojis: return "add_reaction"
      case Search.SearchPrefixType.Math: return "calculate"
      case Search.SearchPrefixType.ShellCommand: return "terminal"
      case Search.SearchPrefixType.WebSearch: return "travel_explore"
      default: return "search"
    }
  }
}
