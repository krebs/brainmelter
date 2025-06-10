#!/usr/bin/env liquidsoap
set("log.level", 3)

set("harbor.bind_addr", "0.0.0.0")
set("harbor.port", 8005)

number_of_harbors = int_of_string(environment.get("BRAINMELTER_HARBORS", default="6"))

input_ids = list.init(number_of_harbors, fun(x) -> x + 1)

inputs = list.map(
  fun(index) -> input.harbor("#{index}", id="#{index}_input", buffer=0.5),
  input_ids
)

fallbacks = list.map(
  fun(index_input) -> fallback(
    track_sensitive=false,
    [snd(index_input), blank(duration=1.0)],
    id="fallback_#{fst(index_input)}"
  ),
  list.indexed(inputs)
)

mixed = add(fallbacks)

out(mixed)

output.harbor(
  %mp3(bitrate=192),
  port=8001,
  mount="brainmelter.mp3",
  mixed
)

print("BrainMelter is running!")
print("Available inputs: #{input_ids}")
print("HTTP stream available at: http://localhost:8001/brainmelter.mp3")
print("System ready!")
