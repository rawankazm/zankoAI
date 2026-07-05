import React from 'react';
import { View, TextInput, Text, StyleSheet } from 'react-native';
import { useThemeColors } from '../context/ThemeContext';
import { useTranslation } from '../context/LanguageContext';

export const CustomInput = ({
  label,
  value,
  onChangeText,
  placeholder,
  secureTextEntry = false,
  keyboardType = 'default',
  multiline = false,
  numberOfLines = 1,
  error = null,
  style,
  inputStyle
}) => {
  const { colors } = useThemeColors();
  const { isRTL } = useTranslation();

  return (
    <View style={[styles.container, style]}>
      {label && (
        <Text style={[styles.label, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
          {label}
        </Text>
      )}
      <View
        style={[
          styles.inputContainer,
          { backgroundColor: colors.inputBackground, borderColor: error ? '#EF4444' : colors.border },
          multiline && { height: Math.max(50, 40 * numberOfLines), alignItems: 'flex-start', paddingTop: 10 }
        ]}
      >
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={colors.subtext}
          secureTextEntry={secureTextEntry}
          keyboardType={keyboardType}
          multiline={multiline}
          style={[
            styles.input,
            { color: colors.text, textAlign: isRTL ? 'right' : 'left' },
            inputStyle
          ]}
        />
      </View>
      {error && (
        <Text style={[styles.errorText, { textAlign: isRTL ? 'right' : 'left' }]}>
          {error}
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    marginVertical: 8,
  },
  label: {
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 6,
    fontFamily: 'Noto Sans Arabic',
  },
  inputContainer: {
    height: 52,
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 16,
    justifyContent: 'center',
  },
  input: {
    fontSize: 15,
    fontFamily: 'Noto Sans Arabic',
    width: '100%',
    height: '100%',
  },
  errorText: {
    color: '#EF4444',
    fontSize: 12,
    marginTop: 4,
    fontFamily: 'Noto Sans Arabic',
  }
});
