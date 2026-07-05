import React from 'react';
import { TouchableOpacity, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { useThemeColors } from '../context/ThemeContext';

export const CustomButton = ({ title, onPress, type = 'primary', loading = false, style, textStyle, disabled = false }) => {
  const { colors } = useThemeColors();

  const buttonStyle = [
    styles.button,
    type === 'primary' && { backgroundColor: colors.primary },
    type === 'outline' && { backgroundColor: 'transparent', borderWidth: 2, borderColor: colors.primary },
    type === 'accent' && { backgroundColor: colors.accent },
    type === 'danger' && { backgroundColor: '#EF4444' },
    disabled && { opacity: 0.5 },
    style
  ];

  const labelStyle = [
    styles.text,
    type === 'outline' ? { color: colors.primary } : { color: '#FFFFFF' },
    textStyle
  ];

  return (
    <TouchableOpacity
      activeOpacity={0.8}
      onPress={onPress}
      style={buttonStyle}
      disabled={disabled || loading}
    >
      {loading ? (
        <ActivityIndicator color={type === 'outline' ? colors.primary : '#FFFFFF'} />
      ) : (
        <Text style={labelStyle}>{title}</Text>
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  button: {
    height: 52,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 1,
  },
  text: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  }
});
