EXEC sp_WhoIsActive
  @show_own_spid = 1,
  @get_plans = 1,
  @get_outer_command = 1,
  @get_transaction_info = 1,
  @get_locks = 1,
  @get_additional_info = 1