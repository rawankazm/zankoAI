import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert, Modal } from 'react-native';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useDatabase } from '../context/DatabaseContext';
import { useAi } from '../context/AiContext';
import { Header } from '../components/Header';
import { Card } from '../components/Card';
import { CustomButton } from '../components/CustomButton';
import { CustomInput } from '../components/CustomInput';
import { MaterialIcons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';
import * as Clipboard from 'expo-clipboard';

export const QuizScreen = () => {
  const { t, isRTL, language } = useTranslation();
  const { colors, isDarkMode } = useThemeColors();
  const { quizzes, addQuiz, incrementQuizzesTaken } = useDatabase();
  const { generateQuiz } = useAi();

  // Screen States
  const [courseName, setCourseName] = useState('');
  const [topic, setTopic] = useState('');
  const [pickedFile, setPickedFile] = useState(null);
  const [isGenerating, setIsGenerating] = useState(false);
  
  // Active Quiz States
  const [activeQuiz, setActiveQuiz] = useState(null);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [userAnswers, setUserAnswers] = useState({});
  const [quizCompleted, setQuizCompleted] = useState(false);
  const [score, setScore] = useState(0);
  const [exportModalVisible, setExportModalVisible] = useState(false);

  const handlePickDocument = async () => {
    try {
      const res = await DocumentPicker.getDocumentAsync({
        type: 'application/pdf',
      });
      if (!res.canceled && res.assets && res.assets.length > 0) {
        setPickedFile(res.assets[0]);
      }
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'Failed to pick a document');
    }
  };

  const handleGenerateQuiz = async () => {
    if (!courseName.trim()) {
      Alert.alert('کۆسپ', 'تکایە ناوی وانە بنووسە');
      return;
    }
    if (!topic.trim() && !pickedFile) {
      Alert.alert('کۆسپ', 'تکایە بابەت یان فایلێک دیاری بکە');
      return;
    }

    setIsGenerating(true);
    setActiveQuiz(null);
    setQuizCompleted(false);
    setUserAnswers({});
    setCurrentQuestionIndex(0);

    try {
      const searchTopic = pickedFile ? pickedFile.name : topic;
      const quiz = await generateQuiz(searchTopic, courseName);
      
      await addQuiz(quiz);
      setActiveQuiz(quiz);
    } catch (e) {
      console.error(e);
      Alert.alert('هەڵە', 'نەتوانرا کویزەکە دروست بکرێت');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleSelectOption = (index, value) => {
    setUserAnswers((prev) => ({
      ...prev,
      [index]: value,
    }));
  };

  const handleSubmitQuiz = () => {
    if (!activeQuiz) return;
    
    let currentScore = 0;
    activeQuiz.questions.forEach((q, i) => {
      const answer = userAnswers[i] || '';
      if (answer.trim().toLowerCase() === q.correctAnswer.trim().toLowerCase()) {
        currentScore++;
      }
    });

    setScore(currentScore);
    setQuizCompleted(true);
    incrementQuizzesTaken();
  };

  const handleExportQuiz = async () => {
    if (!activeQuiz) return;
    
    let text = `==============================\n`;
    text += `ZankoAI - ${activeQuiz.title}\n`;
    text += `وانە: ${activeQuiz.courseName}\n`;
    text += `==============================\n\n`;

    activeQuiz.questions.forEach((q, i) => {
      text += `${i + 1}. ${q.questionText}\n`;
      if (q.type === 'multipleChoice' && q.options) {
        q.options.forEach((opt) => {
          text += `   [ ] ${opt}\n`;
        });
      } else if (q.type === 'trueFalse') {
        text += `   [ ] ڕاستە / True\n`;
        text += `   [ ] هەڵەیە / False\n`;
      } else if (q.type === 'fillInBlank') {
        text += `   بۆشایی پڕ بکەرەوە: __________________\n`;
      }
      text += `   وەڵامی ڕاست (Correct Answer): ${q.correctAnswer}\n\n`;
    });

    await Clipboard.setStringAsync(text);
    Alert.alert('سەرکەوتوو', 'کۆپیکرا بۆ تاشەتەختە (Clipboard)!');
  };

  const resetScreen = () => {
    setActiveQuiz(null);
    setQuizCompleted(false);
    setUserAnswers({});
    setCurrentQuestionIndex(0);
    setTopic('');
    setCourseName('');
    setPickedFile(null);
  };

  const renderCreatorForm = () => (
    <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
      <Card style={styles.cardPadding}>
        <Text style={[styles.cardTitle, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
          {t('generate_quiz_title')}
        </Text>
        <Text style={[styles.cardDesc, { color: colors.subtext, textAlign: isRTL ? 'right' : 'left' }]}>
          {t('generate_quiz_desc')}
        </Text>

        <CustomInput
          label={t('course_name_field')}
          placeholder="e.g. Operating Systems, Networks"
          value={courseName}
          onChangeText={setCourseName}
        />

        {/* File Picker */}
        <TouchableOpacity
          onPress={handlePickDocument}
          style={[styles.filePicker, { borderColor: colors.border, backgroundColor: colors.inputBackground }]}
        >
          <MaterialIcons name="picture-as-pdf" size={20} color={pickedFile ? '#EF4444' : colors.subtext} />
          <Text style={[styles.filePickerText, { color: colors.text }]} numberOfLines={1}>
            {pickedFile ? pickedFile.name : 'بارکردنی فایل (PDF, TXT)'}
          </Text>
        </TouchableOpacity>

        <Text style={[styles.orText, { color: colors.subtext }]}>یان / Or</Text>

        <CustomInput
          label={t('topic_field')}
          placeholder="e.g. Memory management, TCP/IP"
          value={topic}
          onChangeText={setTopic}
          disabled={!!pickedFile}
        />

        <CustomButton
          title={t('generate_quiz_btn')}
          onPress={handleGenerateQuiz}
          style={{ marginTop: 12 }}
        />
      </Card>

      {/* History */}
      <Text style={[styles.sectionTitle, { color: colors.text, marginTop: 24, textAlign: isRTL ? 'right' : 'left' }]}>
        {t('previous_quizzes')}
      </Text>

      {quizzes.length === 0 ? (
        <Text style={[styles.emptyText, { color: colors.subtext, textAlign: 'center' }]}>
          هیچ کویزێکی پێشوو نییە
        </Text>
      ) : (
        quizzes.map((quiz) => (
          <Card
            key={quiz.id}
            onPress={() => {
              setActiveQuiz(quiz);
              setQuizCompleted(false);
              setUserAnswers({});
              setCurrentQuestionIndex(0);
            }}
            style={styles.historyCard}
          >
            <View style={[styles.historyRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
              <View style={[styles.historyIcon, { backgroundColor: colors.badgeBg }]}>
                <MaterialIcons name="assignment" size={24} color={colors.primary} />
              </View>
              <View style={[styles.historyTexts, { alignItems: isRTL ? 'flex-end' : 'flex-start' }]}>
                <Text style={[styles.historyTitle, { color: colors.text }]}>{quiz.title}</Text>
                <Text style={[styles.historyCourse, { color: colors.subtext }]}>{quiz.courseName}</Text>
              </View>
              <MaterialIcons name="play-arrow" size={24} color="#16A34A" />
            </View>
          </Card>
        ))
      )}
    </ScrollView>
  );

  const renderActiveQuiz = () => {
    const question = activeQuiz.questions[currentQuestionIndex];
    const isFirst = currentQuestionIndex === 0;
    const isLast = currentQuestionIndex === activeQuiz.questions.length - 1;
    const currentAnswer = userAnswers[currentQuestionIndex] || '';

    return (
      <View style={styles.quizContainer}>
        {/* Progress Bar Header */}
        <View style={[styles.progressHeader, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <Text style={[styles.quizHeading, { color: colors.text }]} numberOfLines={1}>
            {activeQuiz.title}
          </Text>
          <Text style={[styles.progressText, { color: colors.text }]}>
            {t('question_progress')} {currentQuestionIndex + 1} / {activeQuiz.questions.length}
          </Text>
        </View>

        {/* Progress bar line */}
        <View style={[styles.progressBarOuter, { backgroundColor: colors.border }]}>
          <View
            style={[
              styles.progressBarInner,
              {
                backgroundColor: colors.primary,
                width: `${((currentQuestionIndex + 1) / activeQuiz.questions.length) * 100}%`,
              }
            ]}
          />
        </View>

        <ScrollView contentContainerStyle={styles.quizScrollContent}>
          {/* Question Card */}
          <Card style={styles.questionCard}>
            <Text style={[styles.questionText, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
              {question.questionText}
            </Text>

            <View style={styles.optionsContainer}>
              {question.type === 'trueFalse' && (
                <View>
                  {['ڕاستە', 'هەڵەیە'].map((opt) => (
                    <TouchableOpacity
                      key={opt}
                      activeOpacity={0.8}
                      onPress={() => handleSelectOption(currentQuestionIndex, opt)}
                      style={[
                        styles.radioOption,
                        { borderColor: colors.border },
                        currentAnswer === opt && { backgroundColor: colors.badgeBg, borderColor: colors.primary }
                      ]}
                    >
                      <MaterialIcons
                        name={currentAnswer === opt ? 'radio-button-checked' : 'radio-button-unchecked'}
                        size={20}
                        color={currentAnswer === opt ? colors.primary : colors.subtext}
                        style={{ marginHorizontal: 8 }}
                      />
                      <Text style={[styles.optionText, { color: colors.text }]}>
                        {opt === 'ڕاستە' ? 'ڕاستە / True' : 'هەڵەیە / False'}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              {question.type === 'multipleChoice' && question.options && (
                <View>
                  {question.options.map((opt) => (
                    <TouchableOpacity
                      key={opt}
                      activeOpacity={0.8}
                      onPress={() => handleSelectOption(currentQuestionIndex, opt)}
                      style={[
                        styles.radioOption,
                        { borderColor: colors.border },
                        currentAnswer === opt && { backgroundColor: colors.badgeBg, borderColor: colors.primary }
                      ]}
                    >
                      <MaterialIcons
                        name={currentAnswer === opt ? 'radio-button-checked' : 'radio-button-unchecked'}
                        size={20}
                        color={currentAnswer === opt ? colors.primary : colors.subtext}
                        style={{ marginHorizontal: 8 }}
                      />
                      <Text style={[styles.optionText, { color: colors.text }]}>{opt}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              {question.type === 'fillInBlank' && (
                <TextInput
                  value={currentAnswer}
                  onChangeText={(val) => handleSelectOption(currentQuestionIndex, val)}
                  placeholder="وەڵامەکەت بنووسە..."
                  placeholderTextColor={colors.subtext}
                  style={[
                    styles.blankInput,
                    {
                      color: colors.text,
                      borderColor: colors.border,
                      backgroundColor: colors.inputBackground,
                      textAlign: isRTL ? 'right' : 'left'
                    }
                  ]}
                />
              )}
            </View>
          </Card>

          {/* Navigation buttons */}
          <View style={[styles.quizNavButtons, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
            {!isFirst ? (
              <TouchableOpacity
                onPress={() => setCurrentQuestionIndex(currentQuestionIndex - 1)}
                style={[styles.navButton, { borderColor: colors.primary, borderWidth: 1 }]}
              >
                <Text style={{ color: colors.primary, fontWeight: 'bold' }}>{t('previous_btn')}</Text>
              </TouchableOpacity>
            ) : (
              <View style={styles.navButtonPlaceholder} />
            )}

            <View style={{ width: 12 }} />

            {!isLast ? (
              <TouchableOpacity
                onPress={() => setCurrentQuestionIndex(currentQuestionIndex + 1)}
                style={[styles.navButton, { backgroundColor: colors.primary }]}
              >
                <Text style={{ color: '#FFFFFF', fontWeight: 'bold' }}>{t('next_btn')}</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity
                onPress={handleSubmitQuiz}
                style={[styles.navButton, { backgroundColor: '#16A34A' }]}
              >
                <Text style={{ color: '#FFFFFF', fontWeight: 'bold' }}>{t('submit_btn')}</Text>
              </TouchableOpacity>
            )}
          </View>
        </ScrollView>
      </View>
    );
  };

  const renderQuizResults = () => {
    const totalQuestions = activeQuiz.questions.length;
    const isPerfect = score === totalQuestions;

    return (
      <View style={styles.resultsWrapper}>
        <ScrollView contentContainerStyle={styles.resultsScroll}>
          <Card style={styles.resultsCard}>
            <MaterialIcons
              name="workspace-premium"
              size={100}
              color={isPerfect ? '#D97706' : colors.primary}
              style={styles.badgeIcon}
            />

            <Text style={[styles.resultsTitle, { color: colors.text }]}>
              {t('quiz_completed')}
            </Text>

            <Text style={[styles.scoreTitle, { color: colors.subtext }]}>{t('your_score')}</Text>
            
            <Text style={[styles.scoreValue, { color: isPerfect ? '#16A34A' : colors.primary }]}>
              {score} / {totalQuestions}
            </Text>

            <Text style={[styles.scoreDesc, { color: colors.text }]}>
              {isPerfect ? t('score_perfect') : t('score_good')}
            </Text>

            <View style={styles.resultsButtonRow}>
              <CustomButton
                title={t('back_to_quiz_home')}
                onPress={resetScreen}
                style={{ flex: 1, marginHorizontal: 6 }}
              />
              <TouchableOpacity
                onPress={handleExportQuiz}
                style={[styles.exportBtn, { borderColor: colors.primary }]}
              >
                <MaterialIcons name="content-copy" size={20} color={colors.primary} />
                <Text style={[styles.exportBtnText, { color: colors.primary }]}>کوپیکردن</Text>
              </TouchableOpacity>
            </View>
          </Card>
        </ScrollView>
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <Header title={t('quiz_title')} />

      {isGenerating ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={colors.primary} />
          <Text style={[styles.loadingText, { color: colors.subtext }]}>
            {t('generating_quiz_wait')}
          </Text>
        </View>
      ) : activeQuiz === null ? (
        renderCreatorForm()
      ) : quizCompleted ? (
        renderQuizResults()
      ) : (
        renderActiveQuiz()
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  cardPadding: {
    padding: 20,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  cardDesc: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
    marginVertical: 4,
  },
  filePicker: {
    height: 48,
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
  },
  filePickerText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    marginHorizontal: 8,
    flex: 1,
  },
  orText: {
    fontSize: 12,
    textAlign: 'center',
    marginVertical: 8,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  emptyText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    marginVertical: 20,
  },
  historyCard: {
    marginVertical: 6,
    padding: 12,
  },
  historyRow: {
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  historyIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 10,
  },
  historyTexts: {
    flex: 1,
  },
  historyTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  historyCourse: {
    fontSize: 11,
    marginTop: 2,
    fontFamily: 'Noto Sans Arabic',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
    marginTop: 16,
  },
  quizContainer: {
    flex: 1,
    padding: 16,
  },
  progressHeader: {
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  quizHeading: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    flex: 1,
  },
  progressText: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
  },
  progressBarOuter: {
    height: 6,
    borderRadius: 3,
    width: '100%',
    marginBottom: 20,
    overflow: 'hidden',
  },
  progressBarInner: {
    height: '100%',
    borderRadius: 3,
  },
  quizScrollContent: {
    flexGrow: 1,
  },
  questionCard: {
    padding: 20,
    minHeight: 250,
  },
  questionText: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 24,
  },
  optionsContainer: {
    marginTop: 20,
  },
  radioOption: {
    height: 48,
    borderRadius: 10,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 6,
    paddingHorizontal: 8,
  },
  optionText: {
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
  },
  blankInput: {
    height: 48,
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 16,
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
  },
  quizNavButtons: {
    marginTop: 24,
    width: '100%',
  },
  navButton: {
    flex: 1,
    height: 48,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  navButtonPlaceholder: {
    flex: 1,
  },
  resultsWrapper: {
    flex: 1,
  },
  resultsScroll: {
    padding: 16,
    justifyContent: 'center',
    flexGrow: 1,
  },
  resultsCard: {
    padding: 24,
    alignItems: 'center',
  },
  badgeIcon: {
    marginBottom: 16,
  },
  resultsTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginBottom: 24,
  },
  scoreTitle: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
    textTransform: 'uppercase',
  },
  scoreValue: {
    fontSize: 32,
    fontWeight: 'bold',
    marginVertical: 8,
  },
  scoreDesc: {
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
    textAlign: 'center',
    lineHeight: 22,
    marginVertical: 12,
  },
  resultsButtonRow: {
    flexDirection: 'row',
    width: '100%',
    alignItems: 'center',
    marginTop: 24,
  },
  exportBtn: {
    flexDirection: 'row',
    borderWidth: 1,
    borderRadius: 14,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    marginHorizontal: 6,
  },
  exportBtnText: {
    fontSize: 14,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginHorizontal: 6,
  },
});
