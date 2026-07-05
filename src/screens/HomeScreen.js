import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Grid, Alert, Modal, TextInput } from 'react-native';
import { useAuth } from '../context/AuthContext';
import { useDatabase } from '../context/DatabaseContext';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useAi } from '../context/AiContext';
import { Card } from '../components/Card';
import { MaterialIcons } from '@expo/vector-icons';

export const HomeScreen = ({ navigation }) => {
  const { currentUser, logout } = useAuth();
  const { schedule } = useDatabase();
  const { t, isRTL, language, changeLanguage } = useTranslation();
  const { colors, isDarkMode, toggleTheme } = useThemeColors();
  const { apiKey, saveApiKey, hasRealApiKey } = useAi();

  const [keyModalVisible, setKeyModalVisible] = useState(false);
  const [tempKey, setTempKey] = useState(apiKey || '');
  const [langMenuVisible, setLangMenuVisible] = useState(false);

  const userName = currentUser?.name || 'Student';
  const userRole = currentUser?.role || 'student';
  const userGpa = currentUser?.gpa || 3.65;

  // Filter today's lectures (simulated day - 'شەممە' / Saturday)
  const todayLectures = schedule.filter((item) => item.dayName === 'شەممە').slice(0, 2);

  const handleSaveApiKey = () => {
    saveApiKey(tempKey);
    setKeyModalVisible(false);
    Alert.alert(
      hasRealApiKey ? 'کلیل بە سەرکەوتوویی بەسترا' : 'شێوازی ئۆفلاین چالاک بوو',
      hasRealApiKey ? 'ئێستا وەڵامەکانی مامۆستا لە Gemini وەردەگیرێت.' : 'ئەپەکە شێوازی ناوخۆیی و تاقیکاری بەکاردەهێنێت.'
    );
  };

  const selectLanguage = (code) => {
    changeLanguage(code);
    setLangMenuVisible(false);
  };

  const handleLogout = () => {
    logout();
    navigation.replace('Login');
  };

  const quickShortcuts = [
    { id: 'ai_teacher', label: t('nav_ai_teacher'), icon: 'chat-bubble', desc: t('ask_and_learn'), color: '#2563EB', screen: 'AiTeacherScreen' },
    { id: 'pdf', label: t('nav_courses'), icon: 'picture-as-pdf', desc: t('summarize_and_translate'), color: '#DC2626', screen: 'PdfSummaryScreen' },
    { id: 'flashcards', label: 'فلاشکارد', icon: 'style', desc: 'کارتی یادکردنەوە', color: '#4F46E5', screen: 'FlashcardsScreen' },
    { id: 'gpa', label: 'نەخشەی نمرەکان', icon: 'calculate', desc: 'بەدواداچوونی نمرە', color: '#0D9488', screen: 'GpaTrackerScreen' },
    { id: 'reminders', label: 'یاددەهێنەر', icon: 'alarm', desc: 'ماوە بۆ ئەرکەکان', color: '#EA580C', screen: 'RemindersScreen' },
    { id: 'planner', label: 'پلانی خوێندن بە AI', icon: 'event-note', desc: 'پلانی هەفتانەی خوێندن', color: '#9333EA', screen: 'StudyPlannerScreen' },
    { id: 'timer', label: 'کاتژمێری تەرکیز', icon: 'hourglass-empty', desc: 'شێوازی پۆمۆدۆرۆ', color: '#DB2777', screen: 'FocusScreen' },
    { id: 'stats', label: 'ئامار و میدالیاکانم', icon: 'emoji-events', desc: 'کۆی چالاکییەکان', color: '#D97706', screen: 'StatsScreen' },
  ];

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {/* Header Actions */}
      <View style={[styles.header, { borderBottomColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
        <Text style={[styles.appTitle, { color: colors.text }]}>ZankoAI</Text>
        
        <View style={[styles.headerButtons, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          {/* Language Selector */}
          <TouchableOpacity onPress={() => setLangMenuVisible(true)} style={styles.headerButton}>
            <MaterialIcons name="language" size={24} color={colors.text} />
          </TouchableOpacity>

          {/* Gemini Key Selector */}
          <TouchableOpacity onPress={() => setKeyModalVisible(true)} style={styles.headerButton}>
            <MaterialIcons name="vpn-key" size={24} color={hasRealApiKey ? colors.accent : colors.text} />
          </TouchableOpacity>

          {/* Theme Toggler */}
          <TouchableOpacity onPress={toggleTheme} style={styles.headerButton}>
            <MaterialIcons name={isDarkMode ? 'light-mode' : 'dark-mode'} size={24} color={colors.text} />
          </TouchableOpacity>

          {/* Logout */}
          <TouchableOpacity onPress={handleLogout} style={styles.headerButton}>
            <MaterialIcons name="logout" size={24} color="#EF4444" />
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContainer} showsVerticalScrollIndicator={false}>
        {/* Welcome Row */}
        <View style={[styles.welcomeRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <View style={[styles.welcomeTextContainer, { alignItems: isRTL ? 'flex-end' : 'flex-start' }]}>
            <Text style={[styles.greetingText, { color: colors.primary }]}>
              {t('hello')}، {userName} 👋
            </Text>
            <Text style={[styles.companionText, { color: colors.subtext }]}>
              {t('hello_companion')}
            </Text>
          </View>

          <View style={[styles.roleBadge, { backgroundColor: colors.badgeBg }]}>
            <Text style={[styles.roleText, { color: colors.badgeText }]}>
              {t(userRole)}
            </Text>
          </View>
        </View>

        {/* GPA Progress Card */}
        <Card onPress={() => navigation.navigate('GpaTrackerScreen')} style={[styles.gpaCard, { backgroundColor: colors.primary }]}>
          <View style={[styles.gpaRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
            <View style={[styles.gpaTextColumn, { alignItems: isRTL ? 'flex-end' : 'flex-start' }]}>
              <Text style={styles.gpaLabel}>{t('gpa_title')}</Text>
              <Text style={styles.gpaValue}>
                {language === 'ku' ? `${userGpa} لە کۆی 4.00` : language === 'ar' ? `${userGpa} من 4.00` : `${userGpa} / 4.00`}
              </Text>
              <Text style={styles.gpaSub}>{t('gpa_progress')}</Text>
            </View>
            <View style={styles.gpaIconContainer}>
              <MaterialIcons name="trending-up" size={36} color="#FFFFFF" />
            </View>
          </View>
        </Card>

        {/* AI Suggestion Banner */}
        <View style={[styles.aiSuggestion, { backgroundColor: isDarkMode ? '#1E293B' : '#F0FDF4', borderColor: isDarkMode ? '#334155' : '#BBF7D0', flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <MaterialIcons name="lightbulb-outline" size={24} color="#16A34A" style={styles.aiSuggestIcon} />
          <View style={[styles.aiSuggestContent, { alignItems: isRTL ? 'flex-end' : 'flex-start' }]}>
            <Text style={[styles.aiSuggestTitle, { color: isDarkMode ? '#4ADE80' : '#166534' }]}>
              {t('ai_suggest_title')}
            </Text>
            <Text style={[styles.aiSuggestText, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
              {t('ai_suggest_content')}
            </Text>
          </View>
        </View>

        {/* Today's Lectures TIMETABLE */}
        <View style={[styles.sectionHeaderRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <Text style={[styles.sectionTitle, { color: colors.text }]}>
            {t('today_lectures')}
          </Text>
          <TouchableOpacity onPress={() => navigation.navigate('ScheduleScreen')}>
            <Text style={[styles.viewAllBtn, { color: colors.primary }]}>{t('view_all')}</Text>
          </TouchableOpacity>
        </View>

        {todayLectures.length === 0 ? (
          <Text style={[styles.noLecturesText, { color: colors.subtext, textAlign: 'center' }]}>
            {t('no_lectures_today')}
          </Text>
        ) : (
          todayLectures.map((lecture) => (
            <Card key={lecture.id} onPress={() => navigation.navigate('ScheduleScreen')} style={styles.lectureCard}>
              <View style={[styles.lectureRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                <View style={[styles.lectureIconContainer, { backgroundColor: colors.badgeBg }]}>
                  <MaterialIcons name="bookmark-added" size={24} color={colors.primary} />
                </View>
                <View style={[styles.lectureTextContainer, { alignItems: isRTL ? 'flex-end' : 'flex-start' }]}>
                  <Text style={[styles.lectureName, { color: colors.text }]}>{lecture.courseName}</Text>
                  <Text style={[styles.lectureTime, { color: colors.subtext }]}>
                    {lecture.time} • {lecture.location}
                  </Text>
                </View>
                <MaterialIcons
                  name={isRTL ? 'chevron-left' : 'chevron-right'}
                  size={20}
                  color={colors.subtext}
                  style={styles.chevron}
                />
              </View>
            </Card>
          ))
        )}

        {/* Shortcuts Grid */}
        <Text style={[styles.sectionTitle, { color: colors.text, marginTop: 24, textAlign: isRTL ? 'right' : 'left' }]}>
          {t('quick_access')}
        </Text>

        <View style={styles.gridContainer}>
          {quickShortcuts.map((shortcut) => (
            <TouchableOpacity
              key={shortcut.id}
              activeOpacity={0.8}
              onPress={() => navigation.navigate(shortcut.screen)}
              style={[styles.gridCard, { backgroundColor: colors.card, borderColor: colors.border }]}
            >
              <MaterialIcons name={shortcut.icon} size={28} color={shortcut.color} style={styles.gridIcon} />
              <Text style={[styles.gridTitle, { color: colors.text }]} numberOfLines={1}>
                {shortcut.label}
              </Text>
              <Text style={[styles.gridDesc, { color: colors.subtext }]} numberOfLines={1}>
                {shortcut.desc}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>

      {/* Language Selector Dialog */}
      <Modal visible={langMenuVisible} transparent animationType="fade" onRequestClose={() => setLangMenuVisible(false)}>
        <TouchableOpacity activeOpacity={1} onPress={() => setLangMenuVisible(false)} style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>{t('language_settings')}</Text>
            <TouchableOpacity onPress={() => selectLanguage('ku')} style={styles.langOption}>
              <Text style={[styles.langOptionText, { color: colors.text }]}>کوردی (Kurdish)</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => selectLanguage('ar')} style={styles.langOption}>
              <Text style={[styles.langOptionText, { color: colors.text }]}>العربية (Arabic)</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => selectLanguage('en')} style={styles.langOption}>
              <Text style={[styles.langOptionText, { color: colors.text }]}>English</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* Gemini API Key Dialog */}
      <Modal visible={keyModalVisible} transparent animationType="slide" onRequestClose={() => setKeyModalVisible(false)}>
        <TouchableOpacity activeOpacity={1} onPress={() => setKeyModalVisible(false)} style={styles.modalOverlay}>
          <View style={[styles.keyModalContent, { backgroundColor: colors.card, borderColor: colors.border }]}>
            <Text style={[styles.modalTitle, { color: colors.text }]}>
              {language === 'en' ? 'Connect Gemini Key' : language === 'ar' ? 'ربط مفتاح Gemini' : 'پێوەستکردنی کلیل بۆ Gemini'}
            </Text>
            <Text style={[styles.keyModalDesc, { color: colors.subtext }]}>
              {language === 'en'
                ? 'To enable real AI tutor responses, paste your Gemini API Key below:'
                : language === 'ar'
                ? 'لتمكين إجابات الأستاذ الحقيقية، ألصق مفتاح Gemini API أدناه:'
                : 'بۆ ئەوەی وەڵامەکانی AI مامۆستا ڕاستەقینە بێت، کلیلی Gemini API لەم خوارەوە دابنێ:'}
            </Text>
            
            <TextInput
              value={tempKey}
              onChangeText={setTempKey}
              placeholder="AIzaSy..."
              placeholderTextColor={colors.subtext}
              style={[styles.keyInput, { color: colors.text, borderColor: colors.border, backgroundColor: colors.inputBackground }]}
            />

            <View style={styles.modalButtonRow}>
              <TouchableOpacity onPress={() => setKeyModalVisible(false)} style={styles.modalCancelBtn}>
                <Text style={{ color: colors.primary, fontWeight: 'bold' }}>
                  {language === 'en' ? 'Cancel' : language === 'ar' ? 'إلغاء' : 'پاشگەزبوونەوە'}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={handleSaveApiKey} style={[styles.modalSaveBtn, { backgroundColor: colors.primary }]}>
                <Text style={{ color: '#FFFFFF', fontWeight: 'bold' }}>
                  {language === 'en' ? 'Save' : language === 'ar' ? 'حفظ' : 'پاشەکەوتکردن'}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    height: 56,
    borderBottomWidth: 1,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'space-between',
    elevation: 1,
  },
  appTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  headerButtons: {
    alignItems: 'center',
  },
  headerButton: {
    marginHorizontal: 8,
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollContainer: {
    padding: 16,
    paddingBottom: 32,
  },
  welcomeRow: {
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  welcomeTextContainer: {
    flex: 1,
  },
  greetingText: {
    fontSize: 20,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  companionText: {
    fontSize: 12,
    marginTop: 2,
    fontFamily: 'Noto Sans Arabic',
  },
  roleBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
  },
  roleText: {
    fontSize: 12,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  gpaCard: {
    borderRadius: 16,
    marginVertical: 4,
  },
  gpaRow: {
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  gpaTextColumn: {
    flex: 1,
  },
  gpaLabel: {
    color: 'rgba(255, 255, 255, 0.7)',
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
  },
  gpaValue: {
    color: '#FFFFFF',
    fontSize: 24,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginVertical: 4,
  },
  gpaSub: {
    color: 'rgba(255, 255, 255, 0.7)',
    fontSize: 11,
    fontFamily: 'Noto Sans Arabic',
  },
  gpaIconContainer: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 12,
  },
  aiSuggestion: {
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    marginVertical: 16,
    alignItems: 'flex-start',
  },
  aiSuggestIcon: {
    marginHorizontal: 8,
    marginTop: 2,
  },
  aiSuggestContent: {
    flex: 1,
  },
  aiSuggestTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginBottom: 4,
  },
  aiSuggestText: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 18,
  },
  sectionHeaderRow: {
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  viewAllBtn: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    fontWeight: 'bold',
  },
  noLecturesText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    marginVertical: 12,
  },
  lectureCard: {
    padding: 12,
    marginVertical: 4,
  },
  lectureRow: {
    alignItems: 'center',
  },
  lectureIconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 10,
  },
  lectureTextContainer: {
    flex: 1,
  },
  lectureName: {
    fontSize: 14,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  lectureTime: {
    fontSize: 11,
    marginTop: 2,
    fontFamily: 'Noto Sans Arabic',
  },
  chevron: {
    marginHorizontal: 4,
  },
  gridContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  gridCard: {
    width: '48%',
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    marginVertical: 6,
  },
  gridIcon: {
    marginBottom: 8,
  },
  gridTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  gridDesc: {
    fontSize: 10,
    marginTop: 2,
    fontFamily: 'Noto Sans Arabic',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    width: 250,
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    alignItems: 'stretch',
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    textAlign: 'center',
    marginBottom: 16,
  },
  langOption: {
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0,0,0,0.05)',
  },
  langOptionText: {
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
  },
  keyModalContent: {
    width: '90%',
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
  },
  keyModalDesc: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 18,
    marginVertical: 12,
  },
  keyInput: {
    height: 48,
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: 12,
    fontFamily: 'Noto Sans Arabic',
    fontSize: 14,
    marginBottom: 20,
  },
  modalButtonRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  modalCancelBtn: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    marginHorizontal: 8,
  },
  modalSaveBtn: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
  },
});
