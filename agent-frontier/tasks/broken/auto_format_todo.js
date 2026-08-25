// BROKEN: checkbox states are swapped (done -> [ ], not-done -> [x]).
function formatTodos(items) {
  return items
    .map(function (it) { return (it.done ? '- [ ] ' : '- [x] ') + it.title; })
    .join('\n');
}
