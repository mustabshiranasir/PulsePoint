const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Haversine distance calculation
function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the earth in km
  const dLat = deg2rad(lat2 - lat1);  
  const dLon = deg2rad(lon2 - lon1); 
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2)
    ; 
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  const d = R * c; // Distance in km
  return d;
}

function deg2rad(deg) {
  return deg * (Math.PI/180)
}

exports.notifyNearbyDonors = functions.firestore
  .document("blood_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const bloodGroupNeeded = requestData.bloodGroupNeeded;
    const hospitalLocation = requestData.hospitalLocation; // Map containing geopoint
    const hospitalName = requestData.hospitalName || "A nearby hospital";
    const urgency = requestData.urgencyLevel || "Urgent";
    
    if (!bloodGroupNeeded || !hospitalLocation || !hospitalLocation.geopoint) {
        console.log("Missing blood group or location.", {bloodGroupNeeded, hospitalLocation});
        return null;
    }

    const geopoint = hospitalLocation.geopoint;
    const requestId = context.params.requestId;

    try {
        // Query users where role == "donor", bloodGroup == bloodGroupNeeded, available == true
        const donorsSnapshot = await admin.firestore().collection("users")
            .where("role", "==", "donor")
            .where("bloodGroup", "==", bloodGroupNeeded)
            .where("isAvailable", "==", true)
            .get();

        const tokens = [];

        donorsSnapshot.forEach((doc) => {
            const donorData = doc.data();
            const donorLocation = donorData.location; // Assuming we save GeoPoint in 'location' field
            const fcmToken = donorData.fcmToken;

            if (donorLocation && fcmToken) {
                const distance = getDistanceFromLatLonInKm(
                    geopoint.latitude, geopoint.longitude,
                    donorLocation.latitude, donorLocation.longitude
                );

                if (distance <= 10) { // 10km radius
                    tokens.push(fcmToken);
                }
            }
        });

        if (tokens.length > 0) {
            const message = {
                notification: {
                    title: `Urgent: ${bloodGroupNeeded} Needed`,
                    body: `${hospitalName} needs ${bloodGroupNeeded} blood (${urgency} priority). Tap to view details.`
                },
                data: {
                    requestId: requestId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK"
                },
                tokens: tokens
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`Successfully sent ${response.successCount} messages, failed ${response.failureCount}.`);
        } else {
            console.log("No nearby donors found within 10km.");
        }

    } catch (error) {
        console.error("Error sending notifications:", error);
    }
    
    return null;
  });
