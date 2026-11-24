import type { UserRole } from '@/types/database'
import { createRouter, createWebHistory } from 'vue-router'
import AdminLayout from '@/layouts/AdminLayout.vue'
import AppLayout from '@/layouts/AppLayout.vue'
import SellerLayout from '@/layouts/SellerLayout.vue'
import { useAuthStore } from '@/stores/auth'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    guestOnly?: boolean
    roles?: UserRole[]
    title?: string
  }
}

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior(to, _from, saved) {
    if (saved) return saved
    if (to.hash) return { el: to.hash, top: 72, behavior: 'smooth' }
    return { top: 0 }
  },
  routes: [
    {
      path: '/',
      component: AppLayout,
      children: [
        { path: '', name: 'home', component: () => import('@/views/HomeView.vue') },
        { path: 'shop', name: 'shop', component: () => import('@/views/ShopView.vue'), meta: { title: 'Shop the crafts' } },
        { path: 'product/:slug', name: 'product', component: () => import('@/views/ProductView.vue') },
        { path: 'origins', name: 'origins', component: () => import('@/views/OriginsView.vue'), meta: { title: 'Shop by origin' } },
        { path: 'artisans', name: 'artisans', component: () => import('@/views/ArtisansView.vue'), meta: { title: 'Meet the makers' } },
        { path: 'artisans/:slug', name: 'artisan', component: () => import('@/views/ArtisanView.vue') },
        { path: 'cart', name: 'cart', component: () => import('@/views/CartView.vue'), meta: { title: 'Your cart' } },
        { path: 'checkout', name: 'checkout', component: () => import('@/views/CheckoutView.vue'), meta: { requiresAuth: true, title: 'Checkout' } },
        // Must come before pay/:id so 'maya' isn't read as an order id.
        { path: 'pay/maya/return', name: 'maya-return', component: () => import('@/views/MayaReturnView.vue'), meta: { requiresAuth: true, title: 'Payment' } },
        { path: 'pay/:id', name: 'mock-pay', component: () => import('@/views/MockPayView.vue'), meta: { requiresAuth: true, title: 'Payment' } },
        { path: 'wishlist', name: 'wishlist', component: () => import('@/views/WishlistView.vue'), meta: { requiresAuth: true, title: 'Saved pieces' } },
        { path: 'orders', name: 'orders', component: () => import('@/views/OrdersView.vue'), meta: { requiresAuth: true, title: 'My purchases' } },
        { path: 'orders/:id', name: 'order', component: () => import('@/views/OrderDetailView.vue'), meta: { requiresAuth: true, title: 'Order details' } },
        { path: 'login', name: 'login', component: () => import('@/views/auth/LoginView.vue'), meta: { guestOnly: true, title: 'Log in' } },
        { path: 'register', name: 'register', component: () => import('@/views/auth/RegisterView.vue'), meta: { guestOnly: true, title: 'Create account' } },
        { path: 'forgot-password', name: 'forgot-password', component: () => import('@/views/auth/ForgotPasswordView.vue'), meta: { guestOnly: true, title: 'Forgot password' } },
        { path: 'reset-password', name: 'reset-password', component: () => import('@/views/auth/ResetPasswordView.vue'), meta: { title: 'Set a new password' } },
        { path: 'account', name: 'account', component: () => import('@/views/AccountView.vue'), meta: { requiresAuth: true, title: 'My account' } },
        { path: 'sell', name: 'sell', component: () => import('@/views/SellView.vue'), meta: { requiresAuth: true, title: 'Sell on CraftCebu' } },
      ],
    },
    {
      path: '/seller',
      component: SellerLayout,
      // The owner keeps the owner role when their own shop is approved, so they
      // may open the Seller Centre too; SellerLayout sends anyone without a shop to /sell.
      meta: { requiresAuth: true, roles: ['artisan', 'owner'] },
      children: [
        { path: '', name: 'seller', component: () => import('@/views/seller/SellerDashboardView.vue'), meta: { title: 'Seller Centre' } },
        { path: 'products', name: 'seller-products', component: () => import('@/views/seller/SellerProductsView.vue'), meta: { title: 'My Products' } },
        { path: 'products/new', name: 'seller-product-new', component: () => import('@/views/seller/SellerProductFormView.vue'), meta: { title: 'Add New Product' } },
        { path: 'products/:id/edit', name: 'seller-product-edit', component: () => import('@/views/seller/SellerProductFormView.vue'), meta: { title: 'Edit Product' } },
        { path: 'orders', name: 'seller-orders', component: () => import('@/views/seller/SellerOrdersView.vue'), meta: { title: 'My Orders' } },
        { path: 'income', name: 'seller-income', component: () => import('@/views/seller/SellerIncomeView.vue'), meta: { title: 'My Income' } },
        { path: 'shop', name: 'seller-shop', component: () => import('@/views/seller/SellerShopView.vue'), meta: { title: 'Shop Profile' } },
      ],
    },
    {
      path: '/admin',
      component: AdminLayout,
      meta: { requiresAuth: true, roles: ['owner'] },
      children: [
        { path: '', name: 'admin', component: () => import('@/views/admin/AdminDashboardView.vue'), meta: { title: 'Admin dashboard' } },
        { path: 'applications', name: 'admin-applications', component: () => import('@/views/admin/AdminApplicationsView.vue'), meta: { title: 'Artisan Applications' } },
        { path: 'artisans', name: 'admin-artisans', component: () => import('@/views/admin/AdminArtisansView.vue'), meta: { title: 'All Artisans' } },
        { path: 'orders', name: 'admin-orders', component: () => import('@/views/admin/AdminOrdersView.vue'), meta: { title: 'All Orders' } },
        { path: 'products', name: 'admin-products', component: () => import('@/views/admin/AdminProductsView.vue'), meta: { title: 'All Products' } },
        { path: 'users', name: 'admin-users', component: () => import('@/views/admin/AdminUsersView.vue'), meta: { title: 'Users' } },
        { path: 'reviews', name: 'admin-reviews', component: () => import('@/views/admin/AdminReviewsView.vue'), meta: { title: 'Reviews' } },
        { path: 'payouts', name: 'admin-payouts', component: () => import('@/views/admin/AdminPayoutsView.vue'), meta: { title: 'Payouts' } },
        { path: 'catalog', name: 'admin-catalog', component: () => import('@/views/admin/AdminCatalogView.vue'), meta: { title: 'Catalog Setup' } },
        { path: 'homepage', name: 'admin-homepage', component: () => import('@/views/admin/AdminHomepageView.vue'), meta: { title: 'Homepage' } },
        { path: 'settings', name: 'admin-settings', component: () => import('@/views/admin/AdminSettingsView.vue'), meta: { title: 'Settings' } },
        { path: 'activity', name: 'admin-activity', component: () => import('@/views/admin/AdminActivityView.vue'), meta: { title: 'Activity Log' } },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      component: AppLayout,
      children: [{ path: '', name: 'not-found', component: () => import('@/views/NotFoundView.vue'), meta: { title: 'Page not found' } }],
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.init()

  if (to.meta.guestOnly && auth.user) return { name: auth.isOwner ? 'admin' : 'home' }

  // meta from parent routes is merged into to.meta by vue-router.
  if (to.meta.requiresAuth && !auth.user) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.meta.roles && (!auth.role || !to.meta.roles.includes(auth.role))) {
    return { name: to.meta.roles.includes('artisan') ? 'sell' : 'home' }
  }
})

router.afterEach((to) => {
  // Product and artisan pages set their own title once their data loads.
  if (to.name === 'product' || to.name === 'artisan') return
  document.title = to.meta.title ? `${to.meta.title} · CraftCebu` : 'CraftCebu · Handmade in Cebu'
})

export default router
