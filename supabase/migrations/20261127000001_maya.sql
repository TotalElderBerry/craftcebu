-- Milestone 5: Maya sandbox payments.
-- The Edge Functions call this after confirming a payment's status with Maya
-- itself (never trusting the browser or the webhook body), so only the service
-- role may run it.

create or replace function public.apply_maya_payment(
  p_order_id uuid,
  p_payment_id text,
  p_maya_status text
)
returns public.payment_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_shop uuid;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if v_order.payment_method <> 'maya' then
    raise exception 'Not a Maya order';
  end if;
  -- The payment must belong to the checkout this order started.
  if v_order.maya_checkout_id is distinct from p_payment_id then
    raise exception 'Payment does not match this order';
  end if;

  -- Webhooks can repeat; only an unpaid order changes.
  if v_order.payment_status <> 'unpaid' then
    return v_order.payment_status;
  end if;

  if p_maya_status in ('PAYMENT_SUCCESS', 'AUTHORIZED', 'CAPTURED') then
    update public.orders set payment_status = 'paid' where id = p_order_id;
    return 'paid';
  end if;

  if p_maya_status in ('PAYMENT_FAILED', 'PAYMENT_EXPIRED', 'PAYMENT_CANCELLED', 'PAYMENT_INVALID') then
    update public.orders set payment_status = 'failed' where id = p_order_id;
    for v_shop in select id from public.order_shops where order_id = p_order_id and status = 'pending' loop
      perform public.restock_order_shop(v_shop);
    end loop;
    update public.order_shops set status = 'cancelled' where order_id = p_order_id and status = 'pending';
    return 'failed';
  end if;

  -- Still in progress (PENDING_TOKEN, AUTHENTICATING, ...): nothing to do yet.
  return 'unpaid';
end;
$$;

revoke execute on function public.apply_maya_payment(uuid, text, text) from public, anon, authenticated;
grant execute on function public.apply_maya_payment(uuid, text, text) to service_role;
