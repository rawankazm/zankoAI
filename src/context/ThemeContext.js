import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const ThemeContext = createContext();

export const themeColors = {
  light: {
    dark: false,
    primary: '#1565C0',
    secondary: '#2575FC',
    accent: '#2E7D32',
    background: '#F8FAFC',
    card: '#FFFFFF',
    text: '#0F172A',
    subtext: '#64748B',
    border: '#E2E8F0',
    inputBackground: '#F1F5F9',
    statusBar: 'dark-content',
    badgeText: '#1565C0',
    badgeBg: 'rgba(21, 101, 192, 0.1)',
  },
  dark: {
    dark: true,
    primary: '#1565C0',
    secondary: '#2575FC',
    accent: '#2E7D32',
    background: '#0F172A',
    card: '#1E293B',
    text: '#F8FAFC',
    subtext: '#94A3B8',
    border: '#334155',
    inputBackground: '#334155',
    statusBar: 'light-content',
    badgeText: '#60A5FA',
    badgeBg: 'rgba(96, 165, 250, 0.15)',
  }
};

export const ThemeProvider = ({ children }) => {
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    const loadTheme = async () => {
      try {
        const storedTheme = await AsyncStorage.getItem('user_theme');
        if (storedTheme) {
          setIsDarkMode(storedTheme === 'dark');
        }
      } catch (e) {
        console.error('Failed to load theme', e);
      }
    };
    loadTheme();
  }, []);

  const toggleTheme = async () => {
    try {
      const newValue = !isDarkMode;
      setIsDarkMode(newValue);
      await AsyncStorage.setItem('user_theme', newValue ? 'dark' : 'light');
    } catch (e) {
      console.error('Failed to save theme', e);
    }
  };

  const colors = isDarkMode ? themeColors.dark : themeColors.light;

  return (
    <ThemeContext.Provider value={{ colors, isDarkMode, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useThemeColors = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useThemeColors must be used within a ThemeProvider');
  }
  return context;
};
