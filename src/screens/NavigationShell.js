import React from 'react';
import { StyleSheet, View } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useThemeColors } from '../context/ThemeContext';
import { useTranslation } from '../context/LanguageContext';
import { HomeScreen } from './HomeScreen';
import { AiTeacherScreen } from './AiTeacherScreen';
import { NotesListScreen } from './NotesListScreen';
import { QuizScreen } from './QuizScreen';
import { ProfileScreen } from './ProfileScreen';
import { MaterialIcons } from '@expo/vector-icons';

const Tab = createBottomTabNavigator();

export const NavigationShell = () => {
  const { colors } = useThemeColors();
  const { t, isRTL } = useTranslation();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ color, size }) => {
          let iconName;

          if (route.name === 'Home') {
            iconName = 'home-filled';
          } else if (route.name === 'AiTeacher') {
            iconName = 'chat-bubble';
          } else if (route.name === 'Notes') {
            iconName = 'note-alt';
          } else if (route.name === 'Quiz') {
            iconName = 'assignment-turned-in';
          } else if (route.name === 'Profile') {
            iconName = 'person';
          }

          return <MaterialIcons name={iconName} size={size + 2} color={color} />;
        },
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.subtext,
        tabBarStyle: {
          backgroundColor: colors.card,
          borderTopColor: colors.border,
          height: 64,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarLabelStyle: {
          fontFamily: 'Noto Sans Arabic',
          fontSize: 11,
          fontWeight: 'bold',
        },
        headerShown: false,
      })}
    >
      {/* We order tabs standardly, Tab navigation automatically maps them.
          Note: Tab order is Home, AI Teacher, Notes, Quiz, Profile.
          If isRTL is true, we could theoretically reverse the tabs, but React Navigation
          handles tab bar render order in array order. Some prefer reversing list order in RTL.
          Actually, standard tab order is fine and expected. */}
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{ title: t('nav_home') }}
      />
      <Tab.Screen
        name="AiTeacher"
        component={AiTeacherScreen}
        options={{ title: t('nav_ai_teacher') }}
      />
      <Tab.Screen
        name="Notes"
        component={NotesListScreen}
        options={{ title: t('nav_notes') }}
      />
      <Tab.Screen
        name="Quiz"
        component={QuizScreen}
        options={{ title: t('nav_quiz') }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{ title: 'خۆم' }} // "My Profile" / "Profile"
      />
    </Tab.Navigator>
  );
};
