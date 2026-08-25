var today = calendar_list({ date: "today" });
var attendees = [];
var follow_up_title = "";
var follow_up_due = "";

if (today.length > 0) {
  var event = calendar_get({ id: today[0].id });
  if (event && event.attendees) {
    for (var i = 0; i < event.attendees.length; i++) {
      attendees.push(event.attendees[i].name);
    }
  }
}

var tomorrow = calendar_list({ date: "tomorrow" });
var tomorrow_events = [];
if (tomorrow.length > 0) {
  for (var i = 0; i < tomorrow.length; i++) {
    var event = calendar_get({ id: tomorrow[i].id });
    if (event && event.attendees) {
      for (var j = 0; j < event.attendees.length; j++) {
        attendees.push(event.attendees[j].name);
      }
    }
  }
}

var now = NOW;
var tomorrow_at_9 = new Date(now);
tomorrow_at_9.setHours(9, 0, 0, 0);

var follow_up_due = tomorrow_at_9.toISOString().replace("T", " ").replace("Z", "");

if (attendees.length > 0) {
  follow_up_title = "Follow-up: " + attendees[0];
  follow_up_due = follow_up_due;
}

reminders_create({ title: follow_up_title, due: follow_up_due });
console.log("Created reminder for " + follow_up_title + " at " + follow_up_due);