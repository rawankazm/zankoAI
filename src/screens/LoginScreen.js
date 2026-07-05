import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, SafeAreaView, TouchableOpacity, Alert } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { CustomInput } from '../components/CustomInput';
import { CustomButton } from '../components/CustomButton';
import { MaterialIcons } from '@expo/vector-icons';

export const LoginScreen = ({ navigation }) => {
  const { login, register, loginWithGoogle } = useAuth();
  const { t, isRTL } = useTranslation();
  const { colors } = useThemeColors();

  const [isLoginMode, setIsLoginMode] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState('student'); // student, teacher, admin
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleRoleSelection = (selectedRole) => {
    setRole(selectedRole);
  };

  const validate = () => {
    setError(null);
    if (!email.includes('@') || !email.includes('.')) {
      setError(t('please_enter_email'));
      return false;
    }
    if (password.length < 6) {
      setError(t('please_enter_password'));
      return false;
    }
    if (!isLoginMode && !name.trim()) {
      setError(t('please_enter_name'));
      return false;
    }
    return true;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    setLoading(true);
    let success = false;
    
    if (isLoginMode) {
      success = await login(email, password);
    } else {
      success = await register(name, email, password, role);
    }

    setLoading(false);
    if (success) {
      navigation.replace('NavigationShell');
    } else {
      Alert.alert(
        isLoginMode ? 'هەڵە لە چوونەژوورەوە' : 'هەڵە لە تۆمارکردن',
        'زانیارییەکان ڕاست نین یان هەڵەیەک ڕوویدا'
      );
    }
  };

  const handleGoogleLogin = async () => {
    setLoading(true);
    const success = await loginWithGoogle();
    setLoading(false);
    if (success) {
      navigation.replace('NavigationShell');
    } else {
      Alert.alert('هەڵەی چوونەژوورەوە', 'پەیوەندی بە گووگڵەوە سەرکەوتوو نەبوو');
    }
  };

  const toggleMode = () => {
    setIsLoginMode(!isLoginMode);
    setError(null);
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Logo Container */}
        <View style={styles.logoOuter}>
          <View style={[styles.logoInner, { borderColor: colors.primary + '30' }]}>
            <MaterialIcons name="school" size={70} color={colors.primary} />
          </View>
        </View>

        <Text style={[styles.title, { color: colors.primary }]}>ZankoAI</Text>
        <Text style={[styles.subtitle, { color: colors.subtext }]}>
          {isLoginMode ? t('slogan') : t('register')}
        </Text>

        <View style={styles.form}>
          {!isLoginMode && (
            <CustomInput
              label={t('fullname')}
              placeholder="ئاراس ئەحمەد"
              value={name}
              onChangeText={setName}
            />
          )}

          <CustomInput
            label={t('email')}
            placeholder="example@zanko.edu"
            keyboardType="email-address"
            value={email}
            onChangeText={setEmail}
          />

          <CustomInput
            label={t('password')}
            placeholder="******"
            secureTextEntry
            value={password}
            onChangeText={setPassword}
            error={error}
          />

          {/* Role selector dropdown mockup */}
          {!isLoginMode && (
            <View style={styles.roleContainer}>
              <Text style={[styles.roleLabel, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
                {t('user_role')}
              </Text>
              <View style={[styles.roleRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                {['student', 'teacher', 'admin'].map((r) => (
                  <TouchableOpacity
                    key={r}
                    onPress={() => handleRoleSelection(r)}
                    style={[
                      styles.roleButton,
                      { borderColor: colors.border },
                      role === r && { backgroundColor: colors.primary, borderColor: colors.primary }
                    ]}
                  >
                    <Text
                      style={[
                        styles.roleButtonText,
                        { color: colors.text },
                        role === r && { color: '#FFFFFF', fontWeight: 'bold' }
                      ]}
                    >
                      {t(r)}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          )}

          <CustomButton
            title={isLoginMode ? t('login') : t('register')}
            onPress={handleSubmit}
            loading={loading}
          />

          <View style={styles.separatorContainer}>
            <View style={[styles.line, { backgroundColor: colors.border }]} />
            <Text style={[styles.orText, { color: colors.subtext }]}>یان</Text>
            <View style={[styles.line, { backgroundColor: colors.border }]} />
          </View>

          <TouchableOpacity
            activeOpacity={0.8}
            onPress={handleGoogleLogin}
            style={[styles.googleButton, { borderColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}
          >
            <MaterialIcons name="g-mobiledata" size={32} color="#EA4335" />
            <Text style={[styles.googleButtonText, { color: colors.text }]}>
              {t('google_login')}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={toggleMode} style={styles.toggleButton}>
            <Text style={[styles.toggleButtonText, { color: colors.primary }]}>
              {isLoginMode ? t('no_account') : t('has_account')}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    padding: 24,
    alignItems: 'center',
    justifyContent: 'center',
    flexGrow: 1,
  },
  logoOuter: {
    marginBottom: 16,
  },
  logoInner: {
    width: 110,
    height: 110,
    borderRadius: 55,
    borderWidth: 1.5,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  subtitle: {
    fontSize: 16,
    fontFamily: 'Noto Sans Arabic',
    marginTop: 4,
    marginBottom: 24,
  },
  form: {
    width: '100%',
  },
  roleContainer: {
    marginVertical: 8,
  },
  roleLabel: {
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 8,
    fontFamily: 'Noto Sans Arabic',
  },
  roleRow: {
    justifyContent: 'space-between',
    width: '100%',
  },
  roleButton: {
    flex: 1,
    height: 44,
    borderRadius: 8,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 4,
  },
  roleButtonText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
  },
  separatorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 20,
    width: '100%',
  },
  line: {
    flex: 1,
    height: 1,
  },
  orText: {
    marginHorizontal: 12,
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
  },
  googleButton: {
    height: 52,
    borderWidth: 1,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
    backgroundColor: 'transparent',
  },
  googleButtonText: {
    fontSize: 15,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginHorizontal: 8,
  },
  toggleButton: {
    marginTop: 24,
    alignItems: 'center',
  },
  toggleButtonText: {
    fontSize: 14,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
});
