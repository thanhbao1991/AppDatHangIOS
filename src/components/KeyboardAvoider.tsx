import { KeyboardAvoidingView, Platform, StyleProp, ViewStyle } from 'react-native';

type Props = {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
};

// Dùng chung mọi nơi có TextInput để bàn phím không che nút/nội dung bên dưới - iOS cần behavior
// "padding", Android cần "height".
export default function KeyboardAvoider({ children, style }: Props) {
  return (
    <KeyboardAvoidingView
      style={[{ flex: 1 }, style]}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {children}
    </KeyboardAvoidingView>
  );
}
