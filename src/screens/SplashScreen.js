import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated, ActivityIndicator } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { useThemeColors } from '../context/ThemeContext';
import { useTranslation } from '../context/LanguageContext';
import { MaterialIcons } from '@expo/vector-icons';

export const SplashScreen = ({ navigation }) => {
  const { isAuthenticated, isLoading } = useAuth();
  const { colors } = useThemeColors();
  const { t } = useTranslation();

  // Animation values
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0.8)).current;

  useEffect(() => {
    // Start animations
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 1500,
        useNativeDriver: true,
      }),
      Animated.timing(scaleAnim, {
        toValue: 1,
        duration: 1500,
        useNativeDriver: true,
      }),
    ]).start();

    // Navigation trigger after 3s
    const timer = setTimeout(() => {
      if (!isLoading) {
        if (isAuthenticated) {
          navigation.replace('NavigationShell');
        } else {
          navigation.replace('Login');
        }
      }
    }, 3000);

    return () => clearTimeout(timer);
  }, [isAuthenticated, isLoading]);

  // If Auth finishes loading after the 3 seconds timer
  useEffect(() => {
    if (!isLoading) {
      const timer = setTimeout(() => {
        if (isAuthenticated) {
          navigation.replace('NavigationShell');
        } else {
          navigation.replace('Login');
        }
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [isLoading, isAuthenticated]);

  return (
    <View style={[styles.container, { backgroundColor: colors.primary }]}>
      <Animated.View style={[styles.animatedContainer, { opacity: fadeAnim, transform: [{ scale: scaleAnim }] }]}>
        {/* Glassmorphism Logo container */}
        <View style={styles.logoContainer}>
          <MaterialIcons name="school" size={70} color="#FFFFFF" />
        </View>

        <Text style={styles.title}>ZankoAI</Text>
        <Text style={styles.slogan}>{t('slogan')}</Text>

        <ActivityIndicator size="large" color="#FFFFFF" style={styles.loader} />
      </Animated.View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  animatedContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  logoContainer: {
    width: 130,
    height: 130,
    borderRadius: 65,
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.25)',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 5,
    marginBottom: 24,
  },
  title: {
    fontSize: 42,
    fontWeight: 'bold',
    color: '#FFFFFF',
    fontFamily: 'Cairo',
    letterSpacing: 1.5,
  },
  slogan: {
    fontSize: 18,
    color: 'rgba(255, 255, 255, 0.85)',
    fontFamily: 'Noto Sans Arabic',
    fontWeight: '500',
    marginTop: 8,
  },
  loader: {
    marginTop: 48,
  },
});
