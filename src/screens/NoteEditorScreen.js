import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useDatabase } from '../context/DatabaseContext';
import { useAi } from '../context/AiContext';
import { Header } from '../components/Header';
import { CustomInput } from '../components/CustomInput';
import { MaterialIcons } from '@expo/vector-icons';

export const NoteEditorScreen = ({ route, navigation }) => {
  const { t, isRTL } = useTranslation();
  const { colors } = useThemeColors();
  const { notes, addNote, updateNote, deleteNote } = useDatabase();
  const { organizeNote } = useAi();

  const noteId = route.params?.noteId;
  const isEditing = !!noteId;

  const [title, setTitle] = useState('');
  const [courseName, setCourseName] = useState('');
  const [content, setContent] = useState('');
  const [isAiFormatted, setIsAiFormatted] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isEditing) {
      const note = notes.find((n) => n.id === noteId);
      if (note) {
        setTitle(note.title);
        setCourseName(note.courseName);
        setContent(note.content);
        setIsAiFormatted(note.isAiFormatted);
      }
    }
  }, [noteId, isEditing]);

  const handleSave = async () => {
    if (!title.trim() || !content.trim() || !courseName.trim()) {
      Alert.alert('کۆسپ', 'تکایە هەموو خانەکان پڕبکەرەوە');
      return;
    }

    const noteData = {
      id: isEditing ? noteId : `note_${Date.now()}`,
      title: title.trim(),
      courseName: courseName.trim(),
      content: content.trim(),
      isAiFormatted,
      createdAt: isEditing
        ? notes.find((n) => n.id === noteId)?.createdAt || new Date().toISOString()
        : new Date().toISOString(),
    };

    if (isEditing) {
      await updateNote(noteData);
    } else {
      await addNote(noteData);
    }

    Alert.alert('سەرکەوتوو', t('save_note_success'));
    navigation.goBack();
  };

  const handleDelete = () => {
    Alert.alert(
      'سڕینەوەی تێبینی',
      'ئایا دڵنیایت لە سڕینەوەی ئەم تێبینییە؟',
      [
        { text: 'بەڵێ', onPress: async () => {
            await deleteNote(noteId);
            Alert.alert('سڕایەوە', t('delete_note_success'));
            navigation.goBack();
          }
        },
        { text: 'نەخێر', style: 'cancel' }
      ]
    );
  };

  const handleAiOrganize = async () => {
    if (!content.trim()) return;

    setLoading(true);
    try {
      const organized = await organizeNote(content);
      setContent(organized);
      setIsAiFormatted(true);
    } catch (e) {
      console.error(e);
      Alert.alert('Error', 'AI failed to organize note.');
    } finally {
      setLoading(false);
    }
  };

  const rightHeaderButtons = (
    <View style={styles.headerRightRow}>
      {isEditing && (
        <TouchableOpacity onPress={handleDelete} style={styles.headerBtn}>
          <MaterialIcons name="delete" size={24} color="#EF4444" />
        </TouchableOpacity>
      )}
      <TouchableOpacity onPress={handleSave} style={styles.headerBtn}>
        <MaterialIcons name="check" size={24} color={colors.primary} />
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <Header
        title={isEditing ? t('edit_note_title') : t('new_note_title')}
        showBack
        rightElement={rightHeaderButtons}
      />

      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        <CustomInput
          label={t('note_title_label')}
          placeholder="تێبینی وانە..."
          value={title}
          onChangeText={setTitle}
        />

        <CustomInput
          label={t('note_course_label')}
          placeholder="ناوی کۆرس..."
          value={courseName}
          onChangeText={setCourseName}
        />

        <View style={styles.contentInputContainer}>
          <Text style={[styles.label, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}>
            {t('note_content_label')}
          </Text>
          <TextInput
            value={content}
            onChangeText={setContent}
            placeholder={t('note_content_hint')}
            placeholderTextColor={colors.subtext}
            multiline
            style={[
              styles.textArea,
              {
                backgroundColor: colors.inputBackground,
                color: colors.text,
                borderColor: colors.border,
                textAlign: isRTL ? 'right' : 'left',
              }
            ]}
          />
        </View>

        {content.trim().length > 0 && (
          <TouchableOpacity
            activeOpacity={0.8}
            onPress={handleAiOrganize}
            disabled={loading}
            style={[styles.aiButton, { backgroundColor: colors.accent, flexDirection: isRTL ? 'row-reverse' : 'row' }]}
          >
            {loading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <>
                <MaterialIcons name="auto-awesome" size={20} color="#FFFFFF" style={{ marginHorizontal: 8 }} />
                <Text style={styles.aiButtonText}>{t('ai_organize_btn')}</Text>
              </>
            )}
          </TouchableOpacity>
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  headerRightRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerBtn: {
    marginHorizontal: 8,
    padding: 4,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  contentInputContainer: {
    marginVertical: 8,
  },
  label: {
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 6,
    fontFamily: 'Noto Sans Arabic',
  },
  textArea: {
    height: 250,
    borderRadius: 12,
    borderWidth: 1,
    padding: 16,
    fontSize: 14,
    fontFamily: 'Noto Sans Arabic',
    textAlignVertical: 'top',
  },
  aiButton: {
    height: 52,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  aiButtonText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    fontSize: 15,
  },
});
