import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { GoogleGenAI } from '@google/generative-ai';

const AiContext = createContext();

export const AiProvider = ({ children }) => {
  const [apiKey, setApiKey] = useState(null);
  const [hasRealApiKey, setHasRealApiKey] = useState(false);

  useEffect(() => {
    const loadApiKey = async () => {
      try {
        const storedKey = await AsyncStorage.getItem('gemini_api_key');
        if (storedKey) {
          setApiKey(storedKey);
          setHasRealApiKey(storedKey.trim().length > 0);
        }
      } catch (e) {
        console.error('Failed to load API key', e);
      }
    };
    loadApiKey();
  }, []);

  const saveApiKey = async (key) => {
    try {
      setApiKey(key);
      setHasRealApiKey(key.trim().length > 0);
      await AsyncStorage.setItem('gemini_api_key', key);
    } catch (e) {
      console.error('Failed to save API key', e);
    }
  };

  // Helper to call Gemini model
  const callGemini = async (prompt, systemInstruction = '') => {
    if (!apiKey) throw new Error('No API key configured');
    
    // Initialize the SDK
    const ai = new GoogleGenAI({ apiKey });
    const model = ai.getGenerativeModel({
      model: 'gemini-1.5-flash',
      systemInstruction: systemInstruction || undefined,
    });

    const result = await model.generateContent(prompt);
    const response = await result.response;
    return response.text();
  };

  // AI Teacher Chat
  const askTeacher = async (userPrompt, chatHistory) => {
    await new Promise((resolve) => setTimeout(resolve, 800));

    if (hasRealApiKey) {
      try {
        let historyStr = '';
        chatHistory.forEach((msg) => {
          historyStr += `${msg.role === 'user' ? 'خوێندکار' : 'مامۆستا'}: ${msg.content}\n`;
        });
        const prompt = `${historyStr}خوێندکار: ${userPrompt}\nمامۆستا:`;

        const systemInstruction =
          'تۆ مامۆستایەکی زیرەکی زانکۆیت بە ناوی ZankoAI. وەک مامۆستایەکی دڵسۆز و ڕوون یارمەتی خوێندکارەکە بدە. ' +
          'وەڵامەکانت بە زمانی کوردی (سۆرانی) بن. بە ڕوونی، خاڵبەندی، و بە شێوازێکی فێرکاری و ئەکادیمی وەڵام بدەرەوە.';

        const response = await callGemini(prompt, systemInstruction);
        return response;
      } catch (e) {
        console.error('Gemini error, using mock fallback', e);
        return `📡 **(شێوازی ئۆفلاین - بەستنەوە بەستراو نییە)**\n\n${getMockTeacherResponse(userPrompt)}`;
      }
    }

    return getMockTeacherResponse(userPrompt);
  };

  const getMockTeacherResponse = (userPrompt) => {
    const query = userPrompt.toLowerCase();
    if (query.includes('operating system') || query.includes('سیستەمی کارپێکردن')) {
      return (
        'وەک مامۆستایەکی سیستەمی کارپێکردن (OS)، با ئەمەت بۆ ڕوون بکەمەوە:\n\n' +
        'سیستەمی کارپێکردن گرنگترین نەرمەکاڵایە کە لەسەر کۆمپیوتەر کاردەکات. بەرپرسە لە بەڕێوەبردنی یادگەی کۆمپیوتەرەکە و پرۆسەکان، هەروەها ڕێکخستنی هەموو ڕەقەکاڵا و نەرمەکاڵاکان.\n\n' +
        'سێ ئەرکی سەرەکی OS بریتیین لە:\n' +
        '١. **Processor Management:** دابەشکردنی کات و توانای CPU بەسەر پرۆسە جیاوازەکاندا.\n' +
        '٢. **Memory Management:** چاودێریکردنی چی لە یادگەدایە و کێ بەکاری دەهێنێت.\n' +
        '٣. **File System:** چۆنێتی پاشەکەوتکردن و ڕێکخستنی زانیارییەکان لەسەر دیسک.'
      );
    }

    if (query.includes('کۆد') || query.includes('code') || query.includes('program')) {
      return (
        'با وەک مامۆستایەکی بەرنامەسازی سەیری ئەم کۆدە بکەین:\n\n' +
        'لە فلاتەر و دارتدا، کاتێک دەتەوێت گۆڕانکاری لە ڕوکاری ئەپەکەدا بکەیت، پێویستە `setState` بەکاربهێنیت بۆ ئەوەی فلاتەر بزانێت کە دەبێت ڕوکارەکە نوێ بکاتەوە.\n\n' +
        'بۆ نموونە:\n' +
        '```javascript\n' +
        'const [count, setCount] = useState(0);\n' +
        'const increment = () => {\n' +
        '  setCount(count + 1);\n' +
        '};\n' +
        '```'
      );
    }

    return 'سڵاو خوێندکاری خۆشەویست! من ZankoAI مامۆستای زیرەکی تۆم. لەبەر ئەوەی بەشی ئۆفلاین چالاکە، دەتوانیت پرسیارم لێ بکەیت لەسەر \'سیستەمی کارپێکردن\' یان \'کۆدنووسین\' بۆ بینینی وەڵامی نموونەیی.';
  };

  // PDF Summarizer
  const summarizePdf = async (pdfName, pdfContent) => {
    await new Promise((resolve) => setTimeout(resolve, 1000));

    if (hasRealApiKey) {
      try {
        const prompt =
          `ئەم دەقەی خوارەوە کە لە فایلی بە ناوی '${pdfName}' دەرهێنراوە بە وردی کورت بکەرەوە. ` +
          `وەڵامەکەت پێویستە بە زمانی کوردی (سۆرانی) بێت و سێ بەش لەخۆ بگرێت:\n` +
          `١- کورتهەیەکی گشتی (Summary)\n` +
          `٢- خاڵە سەرەکی و گرنگەکان (Key Points) وەک لیستی خاڵبەندی\n` +
          `٣- وەرگێڕانی گرنگترین پارچەی دەقەکە بۆ کوردی (Translation)\n\n` +
          `دەقەکە:\n${pdfContent}`;

        const responseText = await callGemini(prompt);
        const sections = responseText.split('\n\n');
        
        let summary = sections[0] || responseText;
        const keyPoints = [];
        let translation = 'وەرگێڕان لە دەقی سەرەکییەوە ئەنجامدراوە.';

        const lines = responseText.split('\n');
        lines.forEach((line) => {
          const trimmed = line.trim();
          if (trimmed.startsWith('-') || trimmed.startsWith('*') || /^\d+\./.test(trimmed)) {
            keyPoints.push(trimmed.replace(/^[\-\*\d\.\s]+/, ''));
          }
        });

        if (keyPoints.length === 0) {
          keyPoints.push('سەیری دەقی کورتکراوە بکە بۆ خاڵە سەرەکییەکان.');
        }

        if (sections.length > 2) {
          translation = sections[sections.length - 1];
        }

        return {
          summary,
          keyPoints: keyPoints.slice(0, 5),
          translation,
        };
      } catch (e) {
        console.error('Gemini PDF summary failed', e);
        const mockRes = getMockSummary(pdfName);
        return {
          summary: `📡 **(شێوازی ئۆفلاین)**\n\n${mockRes.summary}`,
          keyPoints: mockRes.keyPoints,
          translation: mockRes.translation,
        };
      }
    }

    return getMockSummary(pdfName);
  };

  const getMockSummary = (pdfName) => {
    return {
      summary: `ئەم فایلە ('${pdfName}') باسی بنەماکانی پەیوەندی لە تۆڕە کۆمپیوتەرییەکاندا دەکات. ڕوونیدەکاتەوە کە چۆن کۆمپیوتەرەکان لە ڕێگەی پرۆتۆکۆلە جیاوازەکانەوە پەیوەندی بەیەکەوە دەکەن بۆ ئاڵوگۆڕکردنی داتا.`,
      keyPoints: [
        'پێناسەی تۆڕ: کۆمەڵێک ئامێرن کە بە یەکەوە بەستراون بۆ هاوبەشکردنی سەرچاوەکان.',
        'مۆدێلی OSI: لە ٧ چین پێکهاتووە (فیزیکی، بەستنی داتا، تۆڕ، گواستنەوە، دانیشتن، پێشکەشکردن، جێبەجێکردن).',
        'پڕۆتۆکۆلی TCP/IP: بنەمای سەرەکی ئینتەرنێتە و گواستنەوەی پارێزراوی زانیارییەکان مسۆگەر دەکات.',
      ],
      translation: 'ئەم پەڕتووکە لەسەر تۆڕەکانی کۆمپیوتەر ڕێبەرییەکی تەواوە بۆ خوێندکارانی بەشی تەکنەلۆجیا تا بە بنەماکانی سویچ، ڕاوتەر و گواستنەوەی پاکەتەکان ئاشنا بن.',
    };
  };

  // Organize Note
  const organizeNote = async (rawNoteContent) => {
    await new Promise((resolve) => setTimeout(resolve, 800));

    if (hasRealApiKey) {
      try {
        const prompt =
          `تکایە ئەم تێبینییە خوارەوە ڕێکبخە و بە شێوازێکی جوان، خاڵبەندی، بە زمانی کوردی (سۆرانی) داڕێژەرەوە. ` +
          `ئەگەر هەڵەی ڕێنووسی تێدایە چاکی بکە و سەردێڕ و خاڵی گرنگی بۆ دابنێ:\n\n${rawNoteContent}`;
        return await callGemini(prompt);
      } catch (e) {
        console.error('Note organization failed', e);
      }
    }

    return (
      `📝 **تێبینی ڕێکخراو بە یارمەتی ZankoAI:**\n\n` +
      `**سەردێڕ:** پێداچوونەوەی بابەت\n\n` +
      `**خاڵە سەرەکییەکان:**\n` +
      `- ${rawNoteContent}\n\n` +
      `*ئەم تێبینییە بە شێوازی فێرکاری و ڕوون ڕێکخراوە بۆ ئاسانکاری لە کاتی خوێندنەوەدا.*`
    );
  };

  // Generate Quiz
  const generateQuiz = async (topic, courseName) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));

    if (hasRealApiKey) {
      try {
        const systemInstruction =
          'You are a quiz generator. You must return a strict JSON array of quiz questions. ' +
          'No markdown, no backticks, no text other than the JSON code itself. ' +
          'Format: [{"id":"q_1","questionText":"...","type":"trueFalse"|"multipleChoice"|"fillInBlank","options":["...","..."],"correctAnswer":"..."}]';
        
        const prompt =
          `Create a quiz on the topic "${topic}" for the course "${courseName}". ` +
          `Create exactly 3 questions. Use Sorani Kurdish for the questions, options, and answers. ` +
          `Ensure the types are diverse: one true/false, one multipleChoice, one fillInBlank.`;

        const response = await callGemini(prompt, systemInstruction);
        const cleanedJson = response.replace(/```json/g, '').replace(/```/g, '').trim();
        const questions = JSON.parse(cleanedJson);

        return {
          id: `quiz_${Date.now()}`,
          title: `تاقیکردنەوەی بابەت: ${topic}`,
          courseName,
          durationMinutes: 10,
          questions,
        };
      } catch (e) {
        console.error('Failed to generate live quiz, using fallback', e);
      }
    }

    return getMockQuiz(topic, courseName);
  };

  const getMockQuiz = (topic, courseName) => {
    return {
      id: `quiz_${Date.now()}`,
      title: `تاقیکردنەوەی بابەت: ${topic}`,
      courseName,
      durationMinutes: 10,
      questions: [
        {
          id: `q_${Date.now()}_1`,
          questionText: `خوێندنی بابەتەکە: ${topic} لە وانەی ${courseName} گرنگە بۆ تێگەیشتنی تەواوی بەشەکان.`,
          type: 'trueFalse',
          correctAnswer: 'ڕاستە',
        },
        {
          id: `q_${Date.now()}_2`,
          questionText: `بەشە گرنگەکانی بابەتەکە چی لەخۆ دەگرێت؟`,
          type: 'multipleChoice',
          options: ['تیۆری و پراکتیک', 'تیۆری بە تەنها', 'پراکتیک بە تەنها', 'هیچیان'],
          correctAnswer: 'تیۆری و پراکتیک',
        },
        {
          id: `q_${Date.now()}_3`,
          questionText: `بۆ تێگەیشتنی باشتری ئەم بابەتە، پێویستە خوێندکار بەردەوام ______ بکات.`,
          type: 'fillInBlank',
          correctAnswer: 'ڕاهێنان',
        },
      ],
    };
  };

  // Generate Flashcards
  const generateFlashcards = async (topicOrText) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));

    if (hasRealApiKey) {
      try {
        const systemInstruction =
          'You are a flashcard generator. You must return a strict JSON array of flashcards. ' +
          'No markdown, no backticks, no text other than the JSON code itself. ' +
          'Format: [{"id":"c_1","front":"...","back":"..."}]';

        const prompt =
          `Create 3 study flashcards in Sorani Kurdish for the topic: "${topicOrText}". ` +
          `Make sure the front has a question/term and the back has a concise explanation.`;

        const response = await callGemini(prompt, systemInstruction);
        const cleanedJson = response.replace(/```json/g, '').replace(/```/g, '').trim();
        const cards = JSON.parse(cleanedJson);
        return cards.map((c, index) => ({
          id: `fc_${Date.now()}_${index}`,
          front: c.front,
          back: c.back,
        }));
      } catch (e) {
        console.error('Failed to generate live flashcards, using fallback', e);
      }
    }

    return [
      {
        id: `fc_${Date.now()}_1`,
        front: `واتای سەرەکی بابەتەکە چییە؟ (${topicOrText.slice(0, 20)})`,
        back: `ڕوونکردنەوەی فێرکاری بۆ بابەتەکە کە ئاسانکاری دەکات بۆ تێگەیشتن و لەبەرکردن بە شێوازێکی خێرا.`,
      },
      {
        id: `fc_${Date.now()}_2`,
        front: `گرنگترین خاڵ چییە لێرەدا؟`,
        back: `کۆششکردنی بەردەوام و پێداچوونەوە لە ڕێگەی بەکارهێنانی کارتی یادکەرەوە.`,
      },
    ];
  };

  // Generate Study Plan
  const generateStudyPlan = async (examTopic, daysRemaining) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));

    if (hasRealApiKey) {
      try {
        const systemInstruction =
          'You are a study planner generator. You must return a strict JSON array representing days. ' +
          'No markdown, no backticks, no text other than the JSON code itself. ' +
          'Format: [{"day":1,"focus":"Day 1 focus topic","tasks":["Task 1","Task 2"]}]';

        const prompt =
          `Generate a study plan in Sorani Kurdish for an exam about "${examTopic}" in ${daysRemaining} days. ` +
          `Distribute study goals daily. Limit to maximum 7 days.`;

        const response = await callGemini(prompt, systemInstruction);
        const cleanedJson = response.replace(/```json/g, '').replace(/```/g, '').trim();
        return JSON.parse(cleanedJson);
      } catch (e) {
        console.error('Failed to generate live study plan, using fallback', e);
      }
    }

    // Fallback Mock study plan
    const plan = [];
    const maxDays = Math.min(daysRemaining, 7);
    for (let d = 1; d <= maxDays; d++) {
      plan.push({
        day: d,
        focus: `ڕۆژی ${d}: پێداچوونەوەی بەشی ${d} لە بابەتەکە`,
        tasks: [
          `خوێندنەوەی دەفتەری تێبینییەکان لەسەر بەشی ${d}`,
          `چارەسەرکردنی پرسیارە نموونەییەکانی بەشی ${d}`,
          `کوتکردنەوەی خاڵە ئاڵۆزەکان بە یارمەتی فلاشکارد`,
        ],
      });
    }
    return plan;
  };

  return (
    <AiContext.Provider value={{ apiKey, hasRealApiKey, saveApiKey, askTeacher, summarizePdf, organizeNote, generateQuiz, generateFlashcards, generateStudyPlan }}>
      {children}
    </AiContext.Provider>
  );
};

export const useAi = () => {
  const context = useContext(AiContext);
  if (!context) {
    throw new Error('useAi must be used within an AiProvider');
  }
  return context;
};
