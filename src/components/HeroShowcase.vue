<script setup lang="ts">
import { ArrowRightIcon } from '@lucide/vue'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import StampBadge from '@/components/StampBadge.vue'
import { categoryImages } from '@/lib/images'
import { cn } from '@/lib/utils'

// Three crafts, each named in Cebuano and tied to the town known for it.
const slides = [
  { slug: 'hablon-weaving', word: 'Hablon', craft: 'Handwoven cloth', town: 'Argao', image: categoryImages['hablon-weaving']!, alt: 'Close-up of colorful handwoven cloth' },
  { slug: 'rattan-wicker', word: 'Uway', craft: 'Rattan and wicker', town: 'Mandaue', image: categoryImages['rattan-wicker']!, alt: 'A woven rattan tote bag with leather handles' },
  { slug: 'guitars-instruments', word: 'Gitara', craft: 'Guitars and ukuleles', town: 'Lapu-Lapu', image: categoryImages['guitars-instruments']!, alt: 'Close-up of a wooden guitar' },
]

const index = ref(0)
const slide = computed(() => slides[index.value]!)

// Auto-advance, paused while hovered or focused and off for reduced motion.
let timer: ReturnType<typeof setInterval> | undefined
const paused = ref(false)
function start() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  timer = setInterval(() => {
    if (!paused.value) index.value = (index.value + 1) % slides.length
  }, 6000)
}
onMounted(start)
onBeforeUnmount(() => clearInterval(timer))
</script>

<template>
  <section
    class="hero-weave relative overflow-hidden text-[oklch(0.97_0.012_80)]"
    aria-roledescription="carousel"
    aria-label="Featured Cebu crafts"
    @mouseenter="paused = true"
    @mouseleave="paused = false"
    @focusin="paused = true"
    @focusout="paused = false"
  >
    <div class="hablon-v absolute inset-y-0 left-0 w-2.5" aria-hidden="true" />

    <div class="relative mx-auto flex min-h-[100svh] max-w-6xl flex-col px-6 pt-24 pb-8 sm:min-h-[820px]">
      <!-- Slide tabs (left) -->
      <ol class="absolute top-1/2 left-6 z-30 hidden -translate-y-1/2 flex-col gap-6 lg:flex" aria-label="Choose a craft">
        <li v-for="(s, i) in slides" :key="s.word">
          <button class="group flex items-center gap-3 text-left" :aria-current="index === i" @click="index = i">
            <span :class="cn('h-px transition-all duration-500', index === i ? 'w-10 bg-mango' : 'w-5 bg-white/40 group-hover:w-8')" />
            <span>
              <span :class="cn('block font-display text-lg transition-opacity', index === i ? 'opacity-100' : 'opacity-55 group-hover:opacity-90')">{{ s.word }}</span>
              <span class="block text-[0.7rem] tracking-wide opacity-55">{{ s.town }}</span>
            </span>
          </button>
        </li>
      </ol>

      <!-- Counter (right) -->
      <div class="absolute top-1/2 right-6 z-30 hidden -translate-y-1/2 flex-col items-center gap-3 lg:flex" aria-hidden="true">
        <span class="font-display text-3xl">0{{ index + 1 }}</span>
        <span class="relative h-24 w-px bg-white/25">
          <span class="absolute inset-x-0 top-0 bg-mango transition-all duration-500" :style="{ height: `${((index + 1) / slides.length) * 100}%` }" />
        </span>
        <span class="text-sm opacity-55">0{{ slides.length }}</span>
      </div>

      <!-- Centerpiece -->
      <div class="relative flex flex-1 flex-col items-center justify-center">
        <p class="relative z-30 flex items-center gap-4 text-sm tracking-[0.3em] uppercase">
          <span class="hablon h-1.5 w-10 rounded-full sm:w-16" aria-hidden="true" />
          Gikan sa {{ slide.town }}
          <span class="hablon h-1.5 w-10 rounded-full sm:w-16" aria-hidden="true" />
        </p>

        <div class="relative mt-6 grid w-full place-items-center">
          <!-- Arch with a thin echo outline and a warm glow behind -->
          <div class="relative z-10 h-[340px] w-[250px] sm:h-[440px] sm:w-[330px]">
            <div class="absolute -inset-10 rounded-full bg-mango/25 blur-3xl" aria-hidden="true" />
            <div class="absolute -inset-3 rounded-t-[999px] rounded-b-2xl border border-white/30" aria-hidden="true" />
            <div class="relative size-full overflow-hidden rounded-t-[999px] rounded-b-2xl bg-black/20 shadow-[0_30px_60px_-20px_rgba(0,0,0,0.6)]">
              <Transition
                enter-active-class="transition duration-700 ease-out"
                enter-from-class="opacity-0 scale-105"
                leave-active-class="transition duration-500 ease-in absolute inset-0"
                leave-to-class="opacity-0"
              >
                <img :key="slide.word" :src="slide.image" :alt="slide.alt" class="size-full object-cover">
              </Transition>
              <!-- Shade the top so the outlined word reads over busy photos -->
              <div class="absolute inset-0 bg-gradient-to-b from-black/55 via-black/15 to-transparent" aria-hidden="true" />
            </div>
            <StampBadge class="absolute -right-10 -bottom-8 z-30 size-24 sm:-right-14 sm:size-28" />
          </div>

          <!-- The giant word, drawn twice: solid behind the arch, outlined in front,
               so the letters turn to line wherever they cross the photo. -->
          <div class="pointer-events-none absolute inset-x-0 top-[12%] grid place-items-center" aria-hidden="true">
            <Transition v-for="layer in ['hero-word z-0', 'hero-word hero-word-outline z-20']" :key="layer" mode="out-in" enter-active-class="transition duration-700 ease-out" enter-from-class="opacity-0 translate-y-4" leave-active-class="transition duration-300 ease-in" leave-to-class="opacity-0">
              <span :key="slide.word" :class="cn(layer, 'col-start-1 row-start-1')">{{ slide.word }}</span>
            </Transition>
          </div>
          <h1 class="sr-only">CraftCebu: {{ slide.craft }} from {{ slide.town }}, sold by the artisans who make it</h1>
        </div>
      </div>

      <!-- Footer row of the hero -->
      <div class="relative z-30 mt-12 flex flex-wrap items-end justify-between gap-6">
        <div>
          <p class="font-display text-lg italic opacity-80">{{ slide.craft }}, hinimo sa</p>
          <p class="font-display text-3xl font-medium sm:text-4xl">Cebuano hands</p>
        </div>
        <div class="flex gap-1 lg:hidden" role="group" aria-label="Choose a craft">
          <!-- The visible bar is small; the button around it is a full tap target -->
          <button
            v-for="(s, i) in slides"
            :key="s.word"
            :aria-label="`Show ${s.word}`"
            :aria-current="index === i"
            class="grid h-11 min-w-11 place-items-center px-2"
            @click="index = i"
          >
            <span :class="cn('block h-1.5 rounded-full transition-all', index === i ? 'w-8 bg-mango' : 'w-3 bg-white/40')" />
          </button>
        </div>
        <RouterLink :to="{ path: '/shop', query: { category: slide.slug } }" class="group flex items-center gap-3 text-sm font-medium">
          Shop {{ slide.word }}
          <span class="grid size-11 place-items-center rounded-full border border-white/50 transition-colors group-hover:border-mango group-hover:bg-mango group-hover:text-ink">
            <ArrowRightIcon class="size-4" />
          </span>
        </RouterLink>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* Deep clay with a faint woven warp-and-weft texture and a soft vignette */
.hero-weave {
  background-color: var(--clay-deep);
  background-image:
    radial-gradient(70% 60% at 50% 45%, oklch(0.5 0.08 50 / 0.55), transparent 70%),
    radial-gradient(120% 90% at 50% 120%, oklch(0 0 0 / 0.35), transparent 60%),
    repeating-linear-gradient(0deg, oklch(1 0 0 / 0.035) 0 1px, transparent 1px 7px),
    repeating-linear-gradient(90deg, oklch(0 0 0 / 0.06) 0 1px, transparent 1px 7px);
}

.hero-word {
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: clamp(5.5rem, 17vw, 14rem);
  line-height: 1;
  letter-spacing: -0.02em;
  color: oklch(0.97 0.012 80);
  position: relative;
}

.hero-word-outline {
  color: transparent;
  -webkit-text-stroke: 2px oklch(0.97 0.012 80);
}
</style>
