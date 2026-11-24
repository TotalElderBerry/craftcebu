<script setup lang="ts">
import { AlertDialog, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { confirmState, settleConfirm } from '@/lib/confirm'
</script>

<template>
  <AlertDialog :open="confirmState.open" @update:open="(v: boolean) => !v && settleConfirm(false)">
    <AlertDialogContent class="w-[calc(100%-2rem)] max-w-md rounded-2xl">
      <AlertDialogHeader>
        <AlertDialogTitle class="font-display text-2xl font-medium">{{ confirmState.options.title }}</AlertDialogTitle>
        <AlertDialogDescription v-if="confirmState.options.body">{{ confirmState.options.body }}</AlertDialogDescription>
      </AlertDialogHeader>
      <AlertDialogFooter class="gap-2">
        <AlertDialogCancel as-child>
          <Button variant="outline" @click="settleConfirm(false)">{{ confirmState.options.cancelLabel ?? 'Cancel' }}</Button>
        </AlertDialogCancel>
        <Button :class="confirmState.options.destructive ? 'bg-destructive hover:bg-destructive/90' : ''" @click="settleConfirm(true)">
          {{ confirmState.options.confirmLabel ?? 'Confirm' }}
        </Button>
      </AlertDialogFooter>
    </AlertDialogContent>
  </AlertDialog>
</template>
