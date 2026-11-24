<script setup lang="ts">
import { computed, ref } from 'vue'

// Single-series line chart with a hover crosshair. The card title names the
// series, so there is no legend box.
const props = defineProps<{
  points: { label: string, value: number }[]
  format: (value: number) => string
  name: string
}>()

const W = 640
const H = 220
const pad = { top: 16, right: 32, bottom: 28, left: 56 }
const plotW = W - pad.left - pad.right
const plotH = H - pad.top - pad.bottom

// Round the top of the axis up to a tidy number so gridlines land on it.
const max = computed(() => {
  const raw = Math.max(...props.points.map(p => p.value), 0)
  if (raw === 0) return 4
  const step = 10 ** Math.floor(Math.log10(raw))
  return Math.ceil(raw / step) * step
})
const ticks = computed(() => [0, 0.25, 0.5, 0.75, 1].map(f => f * max.value))

const x = (i: number) => pad.left + (props.points.length <= 1 ? plotW / 2 : (i / (props.points.length - 1)) * plotW)
const y = (v: number) => pad.top + plotH - (v / max.value) * plotH

const line = computed(() => props.points.map((p, i) => `${i ? 'L' : 'M'}${x(i)},${y(p.value)}`).join(''))
const area = computed(() => `${line.value}L${x(props.points.length - 1)},${pad.top + plotH}L${x(0)},${pad.top + plotH}Z`)

// Show at most ~7 x-axis labels so they never collide.
const labelEvery = computed(() => Math.max(1, Math.ceil(props.points.length / 7)))

const hover = ref<number | null>(null)
function onMove(event: PointerEvent) {
  const svg = (event.currentTarget as SVGElement).ownerSVGElement ?? (event.currentTarget as SVGSVGElement)
  const rect = svg.getBoundingClientRect()
  const px = ((event.clientX - rect.left) / rect.width) * W
  const i = Math.round(((px - pad.left) / plotW) * (props.points.length - 1))
  hover.value = Math.min(props.points.length - 1, Math.max(0, i))
}
</script>

<template>
  <div class="relative">
    <svg :viewBox="`0 0 ${W} ${H}`" class="h-auto w-full" role="img" :aria-label="`${name} chart`">
      <g>
        <template v-for="t in ticks" :key="t">
          <line :x1="pad.left" :x2="W - pad.right" :y1="y(t)" :y2="y(t)" stroke="var(--border)" stroke-width="1" />
          <text :x="pad.left - 8" :y="y(t) + 4" text-anchor="end" font-size="11" fill="var(--muted-foreground)">{{ format(t) }}</text>
        </template>
        <template v-for="(p, i) in points" :key="p.label">
          <text v-if="i % labelEvery === 0 || i === points.length - 1" :x="x(i)" :y="H - 8" text-anchor="middle" font-size="11" fill="var(--muted-foreground)">{{ p.label }}</text>
        </template>
      </g>
      <path :d="area" fill="var(--primary)" fill-opacity="0.08" />
      <path :d="line" fill="none" stroke="var(--primary)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <g v-if="hover !== null && points[hover]">
        <line :x1="x(hover)" :x2="x(hover)" :y1="pad.top" :y2="pad.top + plotH" stroke="var(--muted-foreground)" stroke-dasharray="3 3" />
        <circle :cx="x(hover)" :cy="y(points[hover]!.value)" r="5" fill="var(--primary)" stroke="var(--card)" stroke-width="2" />
      </g>
      <rect :x="pad.left" :y="pad.top" :width="plotW" :height="plotH" fill="transparent" @pointermove="onMove" @pointerleave="hover = null" />
    </svg>
    <div
      v-if="hover !== null && points[hover]"
      class="pointer-events-none absolute top-0 -translate-x-1/2 rounded-md border bg-popover px-3 py-2 text-xs shadow-md"
      :style="{ left: `${(x(hover) / W) * 100}%` }"
    >
      <p class="text-muted-foreground">{{ points[hover]!.label }}</p>
      <p class="mt-0.5 font-semibold tabular-nums">{{ name }}: {{ format(points[hover]!.value) }}</p>
    </div>
    <!-- Table view of the same numbers for screen readers -->
    <table class="sr-only">
      <caption>{{ name }}</caption>
      <tbody>
        <tr v-for="p in points" :key="p.label"><th scope="row">{{ p.label }}</th><td>{{ format(p.value) }}</td></tr>
      </tbody>
    </table>
  </div>
</template>
