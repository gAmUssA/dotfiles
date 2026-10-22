#!/usr/bin/env bash
[ "$SENDER" = "volume_change" ] || exit 0
vol="$INFO"
if   [ "$vol" -ge 60 ]; then icon="󰕾"
elif [ "$vol" -ge 30 ]; then icon="󰖀"
elif [ "$vol" -ge 1 ];  then icon="󰕿"
else icon="󰝟"
fi
sketchybar --set "$NAME" icon="$icon" label="$vol%"
