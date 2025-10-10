import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';

export async function testRemoteConfigFunction() {
  try {
    console.log('Testing Remote Config function...');
    
    const testFunction = httpsCallable(functions, 'updateRemoteConfig');
    
    const testData = {
      parameters: {
        min_app_version: '1.0.0',
        latest_app_version: '1.0.0',
        force_update_enabled: false,
        update_title: 'Test Update',
        update_message: 'This is a test update message',
        play_store_url: 'https://play.google.com/store/apps/details?id=com.test',
        app_store_url: 'https://apps.apple.com/app/id1234567890'
      }
    };
    
    console.log('Sending test data:', testData);
    
    const result = await testFunction(testData);
    
    console.log('Test result:', result);
    
    return result;
  } catch (error) {
    console.error('Test failed:', error);
    throw error;
  }
}
