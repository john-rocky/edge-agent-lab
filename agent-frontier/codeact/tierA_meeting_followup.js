// CodeAct reference: read today's calendar, create one follow-up reminder for 9am the
// next local day, naming the attendee. Loops/branches are in JS; one round of execution.
var today = NOW.slice(0, 10);              // "2026-07-13"
var offset = NOW.slice(19);                // "-07:00" (the device UTC offset)
var events = calendar_list({ date: today });
var meeting = events.filter(function (e) { return e.attendees && e.attendees.length > 0; })[0] || events[0];
var who = (meeting && meeting.attendees && meeting.attendees[0]) || "the attendee";

// next calendar day at 09:00 local
var d = new Date(today + "T00:00:00Z");
d.setUTCDate(d.getUTCDate() + 1);
var nextDay = d.toISOString().slice(0, 10); // "2026-07-14"
var due = nextDay + "T09:00:00" + offset;

reminders_create({ title: "Send follow-up notes to " + who, due: due });
console.log("Created a follow-up reminder for " + who + " at " + due);
