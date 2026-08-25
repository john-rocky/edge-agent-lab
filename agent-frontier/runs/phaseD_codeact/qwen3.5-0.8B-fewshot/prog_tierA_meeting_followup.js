// Define globals as per instructions
const NOW = "2024-01-15T10:00:00.000Z"; // Example date/time for demonstration
const TIMEZONE = "America/New_York"; // Example timezone

// Define functions as per instructions (no imports, no redeclaring)
function calendar_list({ date }) {
  // In a real scenario, this would fetch from a calendar API.
  // For this task, we simulate a calendar with a few events.
  const calendar = {
    2024-01-15: [
      { id: "1", title: "Team Standup", time: "09:00" },
      { id: "2", title: "Project Review", time: "14:00" },
      { id: "3", title: "Lunch", time: "12:00" }
    ]
  };
  return calendar;
}

function calendar_get({ id }) {
  const calendar = calendar_list({ date: NOW });
  return calendar[id];
}

function reminders_create({ title, due, notes }) {
  const now = new Date(NOW);
  now.setHours(9, 0, 0, 0); // Set to 9:00 AM
  const reminder = {
    id: "rem-1",
    title: title,
    due: due,
    notes: notes
  };
  return reminder;
}

function reminders_list({}) {
  const calendar = calendar_list({ date: NOW });
  const reminders = [];
  for (const event of calendar) {
    if (event.title.includes("reminder") || event.title.includes("follow-up")) {
      reminders.push(event);
    }
  }
  return reminders;
}

// Main execution
const calendar = calendar_list({ date: NOW });
const reminder = reminders_create({
  title: "Follow-up Note",
  due: NOW, // Set to today's time
  notes: "Meeting ended. Send this note to the attendee."
});

console.log("Reminder created:", reminder);
console.log("Attendee name:", reminder.title);