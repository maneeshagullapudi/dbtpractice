-- Business rule: every order_item must belong to a valid order.
-- Orphan items indicate CDC ordering issues (item arrived before order) or
-- referential integrity failures in the source database.

select
    oi.order_item_id,
    oi.order_id,
    oi._loaded_at
from {{ ref('stg_order_items') }} as oi
left join {{ ref('stg_orders') }} as o
    on oi.order_id = o.order_id
where o.order_id is null
