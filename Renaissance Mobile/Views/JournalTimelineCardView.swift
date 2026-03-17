//
//  JournalTimelineCardView.swift
//  Renaissance Mobile
//
//  DEPRECATED: This view is no longer used. It was part of the original timeline
//  design and has been superseded by the inline card components in PhotoJournalView
//  and ProcedureEntriesView. This file can be safely deleted from the Xcode project.
//

import SwiftUI

// This type is kept to avoid a dangling reference in the Xcode project file.
// Delete this file via Xcode's "Delete" menu option to fully remove it.
@available(*, deprecated, renamed: "ProcedureEntriesView")
struct JournalTimelineCardView: View {
    let entry: JournalEntry
    var body: some View { EmptyView() }
}
