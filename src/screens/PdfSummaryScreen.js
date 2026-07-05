import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useAi } from '../context/AiContext';
import { Header } from '../components/Header';
import { Card } from '../components/Card';
import { MaterialIcons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';

export const PdfSummaryScreen = () => {
  const { t, isRTL } = useTranslation();
  const { colors } = useThemeColors();
  const { summarizePdf } = useAi();

  const [pickedFile, setPickedFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);

  const handlePickDocument = async () => {
    try {
      const res = await DocumentPicker.getDocumentAsync({
        type: 'application/pdf',
      });

      if (!res.canceled && res.assets && res.assets.length > 0) {
        setPickedFile(res.assets[0]);
        setResults(null); // Clear previous results
      }
    } catch (err) {
      console.error(err);
      Alert.alert('Error', 'Failed to pick a document');
    }
  };

  const handleRunAnalysis = async () => {
    if (!pickedFile) return;

    setLoading(true);
    try {
      // Simulate file reading or use mock text content based on file name
      const mockFileContent = `This is simulated text contents of the PDF named: ${pickedFile.name}. It explains computer architecture, OS concepts, network routers, and memory allocations.`;
      
      const summaryResult = await summarizePdf(pickedFile.name, mockFileContent);
      setResults(summaryResult);
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'AI analysis failed.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <Header title={t('pdf_title')} showBack />

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        {/* Upload Box Area */}
        <TouchableOpacity
          activeOpacity={0.8}
          onPress={handlePickDocument}
          style={[
            styles.uploadBox,
            {
              backgroundColor: colors.card,
              borderColor: colors.border,
              borderStyle: 'dashed',
            }
          ]}
        >
          <MaterialIcons name="picture-as-pdf" size={48} color={pickedFile ? '#EF4444' : colors.subtext} />
          
          <Text style={[styles.uploadTitle, { color: colors.text }]}>
            {pickedFile ? pickedFile.name : t('upload_area_title')}
          </Text>
          
          <Text style={[styles.uploadDesc, { color: colors.subtext }]}>
            {pickedFile
              ? `${(pickedFile.size / (1024 * 1024)).toFixed(2)} MB`
              : t('upload_area_desc')}
          </Text>

          <View style={[styles.pickButton, { backgroundColor: colors.primary }]}>
            <Text style={styles.pickButtonText}>{t('pick_file')}</Text>
          </View>
        </TouchableOpacity>

        {pickedFile && !results && (
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={handleRunAnalysis}
            disabled={loading}
            style={[styles.analyzeButton, { backgroundColor: colors.accent, flexDirection: isRTL ? 'row-reverse' : 'row' }]}
          >
            {loading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <>
                <MaterialIcons name="auto-awesome" size={20} color="#FFFFFF" style={{ marginHorizontal: 8 }} />
                <Text style={styles.analyzeButtonText}>{t('generate_summary_tooltip')}</Text>
              </>
            )}
          </TouchableOpacity>
        )}

        {loading && (
          <View style={styles.waitContainer}>
            <Text style={[styles.waitText, { color: colors.subtext }]}>{t('analyzing_wait')}</Text>
          </View>
        )}

        {/* Results Cards */}
        {results && (
          <View style={styles.resultsContainer}>
            <Text style={[styles.resultHeader, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
              {t('analysis_result')}
            </Text>

            {/* Summary Card */}
            <Card style={styles.resultCard}>
              <View style={[styles.cardHeader, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                <MaterialIcons name="description" size={20} color={colors.primary} />
                <Text style={[styles.cardTitle, { color: colors.text, marginHorizontal: 8 }]}>
                  {t('pdf_summary_card')}
                </Text>
              </View>
              <Text style={[styles.cardBodyText, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
                {results.summary}
              </Text>
            </Card>

            {/* Key Points Card */}
            <Card style={styles.resultCard}>
              <View style={[styles.cardHeader, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                <MaterialIcons name="list" size={20} color={colors.accent} />
                <Text style={[styles.cardTitle, { color: colors.text, marginHorizontal: 8 }]}>
                  {t('key_points_card')}
                </Text>
              </View>
              <View style={styles.bulletList}>
                {results.keyPoints.map((point, index) => (
                  <View key={index} style={[styles.bulletRow, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                    <Text style={{ color: colors.accent, fontWeight: 'bold', marginHorizontal: 6 }}>•</Text>
                    <Text style={[styles.bulletText, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
                      {point}
                    </Text>
                  </View>
                ))}
              </View>
            </Card>

            {/* Translation Card */}
            <Card style={styles.resultCard}>
              <View style={[styles.cardHeader, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
                <MaterialIcons name="translate" size={20} color="#6366F1" />
                <Text style={[styles.cardTitle, { color: colors.text, marginHorizontal: 8 }]}>
                  {t('translation_card')}
                </Text>
              </View>
              <Text style={[styles.cardBodyText, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
                {results.translation}
              </Text>
            </Card>
          </View>
        )}
      </ScrollView>
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
  uploadBox: {
    borderWidth: 2,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 12,
  },
  uploadTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginTop: 16,
    textAlign: 'center',
  },
  uploadDesc: {
    fontSize: 12,
    fontFamily: 'Noto Sans Arabic',
    marginVertical: 8,
    textAlign: 'center',
  },
  pickButton: {
    height: 40,
    borderRadius: 20,
    paddingHorizontal: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 8,
  },
  pickButtonText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    fontSize: 13,
  },
  analyzeButton: {
    height: 52,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginVertical: 12,
  },
  analyzeButtonText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    fontSize: 15,
  },
  waitContainer: {
    alignItems: 'center',
    marginVertical: 20,
  },
  waitText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    textAlign: 'center',
  },
  resultsContainer: {
    marginTop: 16,
  },
  resultHeader: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginBottom: 12,
  },
  resultCard: {
    marginVertical: 6,
  },
  cardHeader: {
    alignItems: 'center',
    marginBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0,0,0,0.05)',
    paddingBottom: 6,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
  },
  cardBodyText: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 20,
  },
  bulletList: {
    marginTop: 4,
  },
  bulletRow: {
    alignItems: 'flex-start',
    marginVertical: 4,
  },
  bulletText: {
    flex: 1,
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 18,
  },
});
