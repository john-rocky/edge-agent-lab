# phone-agent

A text-only tool-calling agent on Google's LiteRT-LM runtime that drives real phone actions from a local
`.litertlm`: the model thinks, calls tools (alarm, timer, calendar read/write, clock), reads the results and answers.
Nothing leaves the phone. First model: [Spark-X2.5-1.7B / 4B](https://huggingface.co/litert-community/Spark-X2.5-1.7B)
(XHToken, Apache-2.0), whose vendor template carries its own tool-call syntax:

```
<tool_call>set_alarm<arg_key>hour</arg_key><arg_value>8</arg_value><arg_key>minute</arg_key><arg_value>10</arg_value>…</tool_call>
```

The runtime's built-in tool-call parser does not know that form (it parses the FunctionGemma, Gemma-4 and JSON
forms), so this app parses it (`SparkToolCalls.kt`), executes (`PhoneTools.kt`) and hands the results back as one
`tool` message with one `ToolResponse` block per call. The bundle's chat template renders the tool list and the tool
role; the list itself goes in through `ConversationConfig.extraContext["tools"]`.

## Model file

The published Spark bundles carry the plain-chat subset of the vendor template. Repack one with the full template
(metadata only; weights byte-identical):

```
python set_prompt_template.py Spark-X2.5-1.7B_int4.litertlm model.litertlm spark25_tools.jinja
```

(`set_prompt_template.py` and `spark25_tools.jinja` live in the converter repo,
[hf-to-litertlm](https://github.com/john-rocky/hf-to-litertlm).) Put the result where the app can mmap it fast —
the app's own files dir, via `run-as`:

```
adb push model.litertlm /data/local/tmp/
adb shell run-as io.github.johnrocky.phoneagent cp /data/local/tmp/model.litertlm files/model.litertlm
```

## Build and run

```
./gradlew :app:installDebug
adb shell pm grant io.github.johnrocky.phoneagent android.permission.READ_CALENDAR
adb shell pm grant io.github.johnrocky.phoneagent android.permission.WRITE_CALENDAR
adb shell am start -n io.github.johnrocky.phoneagent/.MainActivity \
  --es model /data/user/0/io.github.johnrocky.phoneagent/files/model.litertlm \
  --es backend cpu --ei threads 4 --es fixture seed --ez autorun true \
  --es prompt "'Wake me 20 minutes before my 8:30 train tomorrow and put the 50-minute ride on my calendar.'"
```

Extras: `model`, `backend` (`cpu`|`gpu`), `threads`, `prompt`, `name`, `autorun`, `fixture` (`seed` puts two events
on the agent's own calendar for tomorrow; `wipe` deletes that calendar), `cache` (engine cache dir), `notools`.

The agent reads and writes only its own local "Phone Agent" calendar, never an account calendar. Alarms and timers
go to the phone's Clock app through the public `AlarmClock` intents (`EXTRA_SKIP_UI`), so they are real — delete the
alarm afterwards.

## Two things that cost time

- **A locked phone runs a hidden activity in `cpuset:/background`** (little cores): the same model loaded in 2 minutes
  and produced one token a second. The activity therefore sets `showWhenLocked` / `turnScreenOn` / `KEEP_SCREEN_ON`,
  which also lets the whole run be driven and screen-recorded over the lock screen. Check `/proc/<pid>/cgroup`.
- The runtime hands a tool turn to the Jinja template as content blocks (`{type: tool_response, name, response}`),
  not as a string; the template in `spark25_tools.jinja` renders both.
