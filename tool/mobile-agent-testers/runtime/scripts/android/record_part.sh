# Run on Android via adb shell -T sh -s. Never signal a device-wide name/PID lookup.
cd "$1" || exit 1
screenrecord --bit-rate 4000000 --time-limit 180 "$1/part.mp4" </dev/null >/dev/null 2>&1 &
pid=$!
sleep 1
kill -0 "$pid" 2>/dev/null || exit 1
echo ready
while kill -0 "$pid" 2>/dev/null; do
  if [ -e stop ]; then kill -INT "$pid" 2>/dev/null || :; break; fi
  sleep 1
done
wait "$pid" && [ -s part.mp4 ]
