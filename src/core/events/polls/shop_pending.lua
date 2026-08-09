-- Shared pending shop-removal helpers for steal matching.

local M = {}

function M.remove_match(state, item_id, item_type)
  for index, meta in ipairs(state.pending_shop_removals) do
    if meta.item_id == item_id and meta.item_type == item_type then
      table.remove(state.pending_shop_removals, index)
      return meta
    end
  end
  return nil
end

function M.matches_item(state, item_id, item_type)
  for _, meta in ipairs(state.pending_shop_removals) do
    if meta.item_id == item_id and meta.item_type == item_type then
      return true
    end
  end
  return false
end

return M
