import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useThemeColors } from '../context/ThemeContext';
import { useTranslation } from '../context/LanguageContext';
import { MaterialIcons } from '@expo/vector-icons';

export const Header = ({ title, showBack = false, rightElement = null }) => {
  const { colors } = useThemeColors();
  const { isRTL } = useTranslation();
  const navigation = useNavigation();

  return (
    <View style={[styles.header, { backgroundColor: colors.card, borderBottomColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
      {showBack ? (
        <TouchableOpacity
          onPress={() => navigation.goBack()}
          style={styles.backButton}
        >
          <MaterialIcons
            name={isRTL ? 'arrow-forward-ios' : 'arrow-back-ios'}
            size={20}
            color={colors.text}
          />
        </TouchableOpacity>
      ) : (
        <View style={styles.placeholder} />
      )}

      <Text style={[styles.title, { color: colors.text }]}>{title}</Text>

      {rightElement ? (
        <View style={styles.rightElement}>{rightElement}</View>
      ) : (
        <View style={styles.placeholder} />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  header: {
    height: 56,
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    borderBottomWidth: 1,
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  rightElement: {
    minWidth: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  placeholder: {
    width: 40,
  }
});
