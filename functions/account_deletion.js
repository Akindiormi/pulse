async function deleteUserData(database, uid) {
  if (typeof uid !== 'string' || uid.length === 0) throw new TypeError('A valid authenticated UID is required.');
  const userRef = database.collection('users').doc(uid);
  // recursiveDelete removes the user document and every subcollection beneath it.
  // Repeating the operation is safe because an already-clean user path is a no-op.
  await database.recursiveDelete(userRef);
}

module.exports = { deleteUserData };
