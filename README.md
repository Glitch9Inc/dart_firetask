# dart_firetask

Shared Firestore CRUD, batch, and transaction adapters for Glitch9 Dart and
Flutter projects.

## FireTask v2 write semantics

- `create`: creates/replaces the target with the initial model.
- `replace`: full-document replacement.
- `patch`: Firestore `update` for selected fields.
- `delete`: removes the target.
- `update`: legacy-compatible alias for `replace`.

Batch effects such as timestamps and cache changes run only after the server
commit succeeds. A failed commit leaves FireTask-managed cache state unchanged.
A `FireBatch` is single-use and rejects new tasks after commit.

Create batches through the owning client when composing operations:

```dart
final batch = client.createBatch();
await client.batchPatch(model, batch: batch);
await batch.commit();
```

This keeps the batch bound to the client's injected `FirebaseFirestore`
instance, including emulator and secondary-app instances.

Use `FireTransactionRunner` when reads and writes must be concurrency-safe:

```dart
final runner = FireTransactionRunner(firestore: firestore);
await runner.run((transaction) async {
  final snapshot = await transaction.get(reference);
  transaction.update(reference, {'count': snapshot.get('count') + 1});
});
```

## Cache policy

- Successful direct and batch writes update the cache.
- Failed writes do not update it.
- `invalidateCache(id)` removes one cached value.
- `refresh(id)` invalidates and reads it again.
- `clearCache()` clears all cached and negative-cached values.

## Legacy map documents

`FirestoreMapClient` remains available for migration and compatibility with
schemas that store many records inside one Firestore document. New domains
should use one Firestore document per record. Map entries cannot be queried or
patched reliably at arbitrary nested field paths, and large shared documents
remain subject to Firestore size and contention limits.
