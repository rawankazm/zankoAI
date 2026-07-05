import React, { useState, useRef } from 'react';
import { View, Text, StyleSheet, FlatList, TextInput, TouchableOpacity, KeyboardAvoidingView, Platform, ActivityIndicator } from 'react-native';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useAi } from '../context/AiContext';
import { Header } from '../components/Header';
import { MaterialIcons } from '@expo/vector-icons';

export const AiTeacherScreen = () => {
  const { t, isRTL } = useTranslation();
  const { colors } = useThemeColors();
  const { askTeacher, hasRealApiKey } = useAi();

  const [messages, setMessages] = useState([
    {
      id: 'm1',
      role: 'assistant',
      content: 'سڵاو خوێندکاری خۆشەویست! من ZankoAI مامۆستای زیرەکی تۆم. چۆن دەتوانم یارمەتیت بدەم لە خوێندنەکەتدا؟',
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }
  ]);
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(false);
  
  const flatListRef = useRef();

  const handleSend = async () => {
    if (!inputText.trim()) return;

    const userMessage = {
      id: `msg_${Date.now()}`,
      role: 'user',
      content: inputText,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputText('');
    setLoading(true);

    // Prepare history for Gemini API
    const chatHistory = messages.map((m) => ({
      role: m.role,
      content: m.content
    }));

    try {
      const response = await askTeacher(userMessage.content, chatHistory);
      const assistantMessage = {
        id: `msg_${Date.now() + 1}`,
        role: 'assistant',
        content: response,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages((prev) => [...prev, assistantMessage]);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  };

  const renderItem = ({ item }) => {
    const isUser = item.role === 'user';
    return (
      <View style={[styles.messageRow, { flexDirection: isUser ? 'row' : 'row-reverse' }]}>
        <View style={styles.avatarContainer}>
          <MaterialIcons
            name={isUser ? 'person' : 'psychology'}
            size={24}
            color={isUser ? colors.primary : colors.accent}
          />
        </View>
        <View
          style={[
            styles.bubble,
            {
              backgroundColor: isUser ? colors.primary : colors.card,
              borderTopRightRadius: isUser ? 2 : 16,
              borderTopLeftRadius: isUser ? 16 : 2,
              borderColor: colors.border,
              borderWidth: isUser ? 0 : 1,
            }
          ]}
        >
          <Text style={[styles.messageText, { color: isUser ? '#FFFFFF' : colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
            {item.content}
          </Text>
          <Text style={[styles.timeText, { color: isUser ? 'rgba(255,255,255,0.7)' : colors.subtext, textAlign: isUser ? 'right' : 'left' }]}>
            {item.time}
          </Text>
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]}>
      <Header title={t('nav_ai_teacher')} />

      {/* Mode Status Bar */}
      <View style={[styles.statusBar, { backgroundColor: colors.card, borderBottomColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
        <MaterialIcons name={hasRealApiKey ? 'wifi' : 'wifi-off'} size={16} color={hasRealApiKey ? '#16A34A' : '#D97706'} />
        <Text style={[styles.statusText, { color: colors.text }]}>
          {hasRealApiKey ? t('gemini_active') : t('mock_active')}
        </Text>
      </View>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <FlatList
          ref={flatListRef}
          data={messages}
          renderItem={renderItem}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          onContentSizeChange={() => flatListRef.current?.scrollToEnd({ animated: true })}
        />

        {loading && (
          <View style={[styles.thinkingContainer, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
            <ActivityIndicator size="small" color={colors.accent} style={{ marginHorizontal: 8 }} />
            <Text style={[styles.thinkingText, { color: colors.subtext }]}>{t('ai_thinking')}</Text>
          </View>
        )}

        {/* Input Bar */}
        <View style={[styles.inputBar, { backgroundColor: colors.card, borderTopColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <TextInput
            value={inputText}
            onChangeText={setInputText}
            placeholder={t('ask_teacher_hint')}
            placeholderTextColor={colors.subtext}
            style={[styles.textInput, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}
          />
          <TouchableOpacity
            onPress={handleSend}
            disabled={!inputText.trim()}
            style={[styles.sendButton, { backgroundColor: inputText.trim() ? colors.primary : colors.border }]}
          >
            <MaterialIcons name={isRTL ? 'arrow-back' : 'send'} size={20} color="#FFFFFF" />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

// Simple import fallback
import { SafeAreaView } from 'react-native-safe-area-context';

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  statusBar: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    alignItems: 'center',
  },
  statusText: {
    fontSize: 11,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginHorizontal: 8,
  },
  listContent: {
    padding: 16,
    paddingBottom: 24,
  },
  messageRow: {
    marginVertical: 6,
    alignItems: 'flex-start',
    width: '100%',
  },
  avatarContainer: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.02)',
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 8,
  },
  bubble: {
    flex: 1,
    maxWidth: '75%',
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  messageText: {
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 22,
  },
  timeText: {
    fontSize: 9,
    marginTop: 4,
  },
  thinkingContainer: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    alignItems: 'center',
  },
  thinkingText: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
  },
  inputBar: {
    padding: 12,
    alignItems: 'center',
    borderTopWidth: 1,
  },
  textInput: {
    flex: 1,
    height: 44,
    borderRadius: 22,
    paddingHorizontal: 16,
    backgroundColor: 'rgba(0,0,0,0.03)',
    fontFamily: 'Noto Sans Arabic',
    fontSize: 14,
    marginHorizontal: 8,
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
