import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { useThemeColors } from '../context/ThemeContext';

export const Card = ({ children, style, onPress, activeOpacity = 0.9 }) => {
  const { colors } = useThemeColors();

  const cardStyle = [
    styles.card,
    {
      backgroundColor: colors.card,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: colors.dark ? 0.3 : 0.05,
      shadowRadius: 8,
      elevation: 2,
    },
    style
  ];

  if (onPress) {
    return (
      <TouchableOpacity onPress={onPress} activeOpacity={activeOpacity} style={cardStyle}>
        {children}
      </TouchableOpacity>
    );
  }

  return <View style={cardStyle}>{children}</View>;
};

const styles = StyleSheet.create({
  card: {
    borderRadius: 16,
    padding: 16,
    marginVertical: 8,
  }
});
