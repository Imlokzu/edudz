# edudz design

A calm school planner: warm paper, forest green, soft mint, readable Manrope.
The three strokes of the mark represent the daily list: timetable, tasks, progress.

- Paper #F6F5F0; forest #1B5245; mint #DDEBC8; ink #24352F.
- Locally bundled Manrope (SIL OFL). 36px headlines, 16px titles, 14px body.
- 24px screen gutters, 22px content radii, 28px feature card radius.
- At 700px+, use a navigation rail; at 1000px+, show lesson/homework details beside the list. Portrait tablet details remain readable as a full page.
- Five destinations: Today, Schedule, Tasks, Grades, Inbox.
- White flat surfaces, subtle color-coded timetable strokes, no decorative gradients.
- Dates and grades retain the school's meaning. No fabricated grade averages.
- Demo must always carry a visible sample-data notice.
- Failures show saved data, retry controls and the last successful sync time.
- Task completion is local to this installation, clearly stated in the detail sheet.
- Ukrainian, English, German; light and dark themes; scrollable compact screens.

Source of truth: lib/edudz/theme.dart and assets/edudz.svg.

Assistant: a focused, scrollable chat with progressive Markdown answers, stop/retry controls, readable status and attachment chips.
