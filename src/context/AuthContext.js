import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // Preloaded mock users
  const defaultStudent = {
    id: 'mock_user_123',
    name: 'ئاراس ئەحمەد',
    email: 'aras@zanko.edu',
    role: 'student',
    universityName: 'زانکۆی سلێمانی',
    departmentName: 'تەکنەلۆجیای زانیاری',
    gpa: 3.65,
    gpaHistory: [3.2, 3.4, 3.65, 3.8]
  };

  useEffect(() => {
    const checkAuthState = async () => {
      try {
        const storedUser = await AsyncStorage.getItem('auth_user');
        if (storedUser) {
          setCurrentUser(JSON.parse(storedUser));
        } else {
          // Preload default student on fresh install/restart so it is easy to test
          setCurrentUser(defaultStudent);
          await AsyncStorage.setItem('auth_user', JSON.stringify(defaultStudent));
        }
      } catch (e) {
        console.error('Failed to load auth user', e);
      } finally {
        setIsLoading(false);
      }
    };
    checkAuthState();
  }, []);

  const login = async (email, password) => {
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 800)); // Latency simulation
    
    if (email.trim() && password.length >= 6) {
      const normalizedEmail = email.toLowerCase().trim();
      let user = null;

      if (normalizedEmail === 'aras@zanko.edu') {
        user = defaultStudent;
      } else {
        const namePart = normalizedEmail.split('@')[0];
        const formattedName = namePart.charAt(0).toUpperCase() + namePart.slice(1);
        user = {
          id: `mock_user_${Date.now()}`,
          name: formattedName,
          email: email.trim(),
          role: 'student',
          universityName: 'زانکۆی سلێمانی',
          departmentName: 'تەکنەلۆجیای زانیاری',
          gpa: 3.5,
          gpaHistory: [3.0, 3.25, 3.4, 3.5]
        };
      }
      setCurrentUser(user);
      await AsyncStorage.setItem('auth_user', JSON.stringify(user));
      setIsLoading(false);
      return true;
    }
    setIsLoading(false);
    return false;
  };

  const register = async (name, email, password, role) => {
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 800));
    
    const newUser = {
      id: `mock_user_${Date.now()}`,
      name: name.trim(),
      email: email.toLowerCase().trim(),
      role: role || 'student',
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: 3.65,
      gpaHistory: [3.2, 3.4, 3.65]
    };
    
    setCurrentUser(newUser);
    await AsyncStorage.setItem('auth_user', JSON.stringify(newUser));
    setIsLoading(false);
    return true;
  };

  const loginWithGoogle = async () => {
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    
    const googleUser = {
      id: 'google_user_999',
      name: 'ڕاوەن شێرکۆ',
      email: 'rawan.sherko@gmail.com',
      role: 'student',
      universityName: 'زانکۆی سلێمانی',
      departmentName: 'تەکنەلۆجیای زانیاری',
      gpa: 3.82,
      gpaHistory: [3.5, 3.68, 3.75, 3.82]
    };
    
    setCurrentUser(googleUser);
    await AsyncStorage.setItem('auth_user', JSON.stringify(googleUser));
    setIsLoading(false);
    return true;
  };

  const logout = async () => {
    setIsLoading(true);
    await new Promise((resolve) => setTimeout(resolve, 300));
    setCurrentUser(null);
    await AsyncStorage.removeItem('auth_user');
    setIsLoading(false);
  };

  const updateUserGpa = async (newGpa, newHistory) => {
    if (!currentUser) return;
    const updatedUser = {
      ...currentUser,
      gpa: newGpa,
      gpaHistory: newHistory || currentUser.gpaHistory
    };
    setCurrentUser(updatedUser);
    await AsyncStorage.setItem('auth_user', JSON.stringify(updatedUser));
  };

  return (
    <AuthContext.Provider
      value={{
        currentUser,
        isAuthenticated: !!currentUser,
        isLoading,
        login,
        register,
        loginWithGoogle,
        logout,
        updateUserGpa
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
