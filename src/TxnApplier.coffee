transaction = require './transaction'

# You throw transactions at this.
# It figures out what to apply immediately and what to buffer
# to apply later if the incoming transaction has to wait first for
# another transaction.
module.exports = TxnApplier = (startingIndex) ->
  # corresponds to verToWrite in Store
  # corresponds to nextNum in Model
  @_serializingIndex = if startingIndex isnt undefined then startingIndex else 1
  @_pending = {}
  return

TxnApplier::=
  PERIOD: 500
  add: (index, txn) ->
    serializingIndex = @_serializingIndex
    # Cache this transaction to be applied later if it is not the next
    # serializingIndex
    if index > serializingIndex
      @_pending[index] = txn
      @waiter ||= @waitForDependencies
      return true
    # Ignore this transaction if it is older than the current index
    return false if index < serializingIndex
    # Otherwise apply it immediately
    @applyTxn txn
    # And apply any transactions that were waiting for txn
    @_serializingIndex++
    @flushValidPending()
    return true
  flushValidPending: ->
    pending = @_pending
    serializingIndex = @_serializingIndex
    while txn = pending[serializingIndex]
      @applyTxn txn
      delete pending[serializingIndex++]
    @_serializingIndex = serializingIndex
  clear: ->
    serializingIndex = @_serializingIndex
    pending = @_pending
    for i of pending
      delete pending[i] if i < serializingIndex
  stopWaitingForDependencies: ()->
    if @waiter
      @clearWaiter @waiter if @clearWaiter
      @waiter = null