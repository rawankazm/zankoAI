import React, { createContext, useContext, useState, useEffect } from 'react';
import { I18nManager } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { translations } from '../utils/translations';

const LanguageContext = createContext();

export const LanguageProvider = ({ children }) => {
  const [language, setLanguageState] = useState('ku'); // Default to Kurdish

  useEffect(() => {
    // Load language from storage
    const loadLanguage = async () => {
      try {
        const storedLanguage = await AsyncStorage.getItem('user_language');
        if (storedLanguage) {
          setLanguageState(storedLanguage);
        }
      } catch (e) {
        console.error('Failed to load language', e);
      }
    };
    loadLanguage();
  }, []);

  const changeLanguage = async (newLang) => {
    try {
      setLanguageState(newLang);
      await AsyncStorage.setItem('user_language', newLang);
      
      // Handle RTL layouts
      const isRTL = newLang === 'ku' || newLang === 'ar';
      if (I18nManager.isRTL !== isRTL) {
        I18nManager.forceRTL(isRTL);
        // On React Native, changing RTL may require a reload, but we can also handle it 
        // dynamically in styled components by checking isRTL from context!
      }
    } catch (e) {
      console.error('Failed to save language', e);
    }
  };

  const t = (key) => {
    if (!translations[key]) return key;
    return translations[key][language] || key;
  };

  const isRTL = language === 'ku' || language === 'ar';

  return (
    <LanguageContext.Provider value={{ language, changeLanguage, t, isRTL }}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useTranslation = () => {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useTranslation must be used within a LanguageProvider');
  }
  return context;
};
