// Blip friends game: the online service that swaps daily points totals (Firebase, free tier).
// Fill these two in from Firebase console > Project settings > General > Your apps > Web app.
// Both are public by design (the security rules in friends/firestore.rules protect the data).
// Left empty, the app still counts points and offers a practice match, but can't connect friends.
window.FRIENDS_CONFIG = {
  apiKey: '',
  projectId: ''
};
