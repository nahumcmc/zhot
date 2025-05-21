#!/bin/bash

# Detectar el entorno de visualización (Wayland o X11)
detect_environment() {
  if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "wayland"
  elif [ -n "$DISPLAY" ]; then
    echo "x11"
  else
    echo "unknown"
  fi
}

# Función para capturar pantalla en Wayland o X11
capture() {
  local output_file="$1"
  local env=$(detect_environment)
  
  case "$env" in
    wayland)
      # Usar grim y slurp para Wayland
      if ! command -v grim &> /dev/null || ! command -v slurp &> /dev/null; then
        notify-send "❌ Error" "Se requiere grim y slurp para capturas en Wayland"
        exit 1
      fi
      grim -g "$(slurp)" "$output_file"
      ;;
    x11)
      # Usar maim para X11
      if ! command -v maim &> /dev/null; then
        notify-send "❌ Error" "Se requiere maim para capturas en X11"
        exit 1
      fi
      maim -s "$output_file"
      ;;
    *)
      notify-send "❌ Error" "No se pudo detectar un entorno gráfico compatible"
      exit 1
      ;;
  esac
}

# Función para mostrar imagen
display_image() {
  local image_file="$1"
  
  # Intentar con feh primero
  if command -v feh &> /dev/null; then
    feh "$image_file" &
  # Alternativa con xdg-open
  elif command -v xdg-open &> /dev/null; then
    xdg-open "$image_file" &
  # Alternativa con ristretto
  elif command -v ristretto &> /dev/null; then
    ristretto "$image_file" &
  # Alternativa con eog (Eye of GNOME)
  elif command -v eog &> /dev/null; then
    eog "$image_file" &
  else
    notify-send "⚠️ Advertencia" "No se encontró un visor de imágenes"
  fi
}

# Función para copiar al portapapeles
copy_to_clipboard() {
  local file="$1"
  local env=$(detect_environment)
  
  case "$env" in
    wayland)
      # Usar wl-copy para Wayland
      if ! command -v wl-copy &> /dev/null; then
        notify-send "❌ Error" "Se requiere wl-clipboard para copiar en Wayland"
        return 1
      fi
      wl-copy < "$file"
      ;;
    x11)
      # Usar xclip para X11
      if command -v xclip &> /dev/null; then
        xclip -selection clipboard -t image/png -i "$file"
      # Alternativa con xsel
      elif command -v xsel &> /dev/null; then
        xsel -i -b < "$file"
      else
        notify-send "❌ Error" "Se requiere xclip o xsel para copiar en X11"
        return 1
      fi
      ;;
    *)
      notify-send "❌ Error" "No se pudo detectar un entorno gráfico compatible"
      return 1
      ;;
  esac
  
  return 0
}

# Función para configurar el alias en diferentes shells
configure_alias() {
  SCRIPT_PATH=$(readlink -f "$0")
  
  # Comprobar si el script ya está en PATH
  if ! command -v zhot &> /dev/null && [ "$SCRIPT_PATH" != "/usr/local/bin/zhot" ]; then
    echo "⚠️ El script no está en PATH. Considera moverlo a /usr/local/bin/"
    echo "   sudo cp \"$SCRIPT_PATH\" /usr/local/bin/zhot"
    echo "   sudo chmod +x /usr/local/bin/zhot"
  fi
  
  # Configurar para Bash
  if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "alias zhot=" "$HOME/.bashrc"; then
      echo "alias zhot=\"$SCRIPT_PATH\"" >> "$HOME/.bashrc"
      echo "✅ Alias configurado en Bash (.bashrc)"
    else
      echo "ℹ️ El alias ya existe en .bashrc"
    fi
  fi
  
  # Configurar para Zsh
  if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "alias zhot=" "$HOME/.zshrc"; then
      echo "alias zhot=\"$SCRIPT_PATH\"" >> "$HOME/.zshrc"
      echo "✅ Alias configurado en Zsh (.zshrc)"
    else
      echo "ℹ️ El alias ya existe en .zshrc"
    fi
  fi
  
  # Configurar para Fish
  if [ -d "$HOME/.config/fish" ]; then
    FISH_ALIASES="$HOME/.config/fish/config.fish"
    if [ -f "$FISH_ALIASES" ]; then
      if ! grep -q "alias zhot=" "$FISH_ALIASES"; then
        echo "alias zhot=\"$SCRIPT_PATH\"" >> "$FISH_ALIASES"
        echo "✅ Alias configurado en Fish (config.fish)"
      else
        echo "ℹ️ El alias ya existe en config.fish"
      fi
    else
      echo "alias zhot=\"$SCRIPT_PATH\"" > "$FISH_ALIASES"
      echo "✅ Alias configurado en Fish (nuevo config.fish creado)"
    fi
  fi
  
  echo ""
  echo "🔄 Para activar el alias en la sesión actual, ejecuta:"
  echo "   source ~/.bashrc    # Si usas Bash"
  echo "   source ~/.zshrc     # Si usas Zsh"
  echo "   source ~/.config/fish/config.fish  # Si usas Fish"
}

# Comprobar dependencias
check_dependencies() {
  local env=$(detect_environment)
  local missing=""
  
  # Dependencias comunes
  if ! command -v zenity &> /dev/null; then missing="$missing zenity"; fi
  if ! command -v notify-send &> /dev/null; then missing="$missing libnotify-bin"; fi
  
  # Dependencias específicas por entorno
  case "$env" in
    wayland)
      if ! command -v grim &> /dev/null; then missing="$missing grim"; fi
      if ! command -v slurp &> /dev/null; then missing="$missing slurp"; fi
      if ! command -v wl-copy &> /dev/null; then missing="$missing wl-clipboard"; fi
      ;;
    x11)
      if ! command -v maim &> /dev/null; then missing="$missing maim"; fi
      if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then 
        missing="$missing xclip/xsel"; 
      fi
      ;;
  esac
  
  # Dependencias para visualización (al menos una)
  if ! command -v feh &> /dev/null && 
     ! command -v xdg-open &> /dev/null &&
     ! command -v ristretto &> /dev/null &&
     ! command -v eog &> /dev/null; then
    missing="$missing feh/visor-de-imágenes";
  fi
  
  # Mostrar mensaje si faltan dependencias
  if [ -n "$missing" ]; then
    echo "⚠️ Faltan las siguientes dependencias:$missing"
    echo "Instala las dependencias según tu distribución:"
    echo "  Debian/Ubuntu: sudo apt install$missing"
    echo "  Arch: sudo pacman -S$missing"
    echo "  Fedora: sudo dnf install$missing"
    echo ""
    read -p "¿Deseas continuar de todos modos? [s/N] " answer
    if [[ ! "$answer" =~ ^[Ss]$ ]]; then
      exit 1
    fi
  fi
}

# Ayuda
show_help() {
  echo "Uso: zhot [opción]"
  echo " -c, --clipboard   Capturar y copiar al portapapeles"
  echo " -s, --save        Capturar y guardar en ~/Pictures/Screenshots"
  echo " -w, --where       Elegir carpeta donde guardar usando selector"
  echo " -i, --install     Configurar alias zhot en tu shell (bash/zsh/fish)"
  echo " -d, --deps        Comprobar dependencias necesarias"
  echo " -h, --help        Mostrar esta ayuda"
  echo ""
  echo "Funciona tanto en Wayland (grim/slurp) como en X11 (maim)"
}

# Lógica del script
case "$1" in
  -c|--clipboard)
    DIR="$HOME/Pictures/Screenshots"
    mkdir -p "$DIR"
    FILE="$DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    capture "$FILE"
    
    if copy_to_clipboard "$FILE"; then
      notify-send "📸 Captura copiada al portapapeles" "$FILE"
      display_image "$FILE"
    fi
    ;;
    
  -s|--save)
    DIR="$HOME/Pictures/Screenshots"
    mkdir -p "$DIR"
    FILE="$DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    capture "$FILE"
    notify-send "📸 Captura guardada" "$FILE"
    display_image "$FILE"
    ;;
    
  -w|--where)
    # Crear directorio temporal
    DIR="$HOME/Pictures/Screenshots"
    mkdir -p "$DIR"

    # Crear nombre del archivo temporal
    FILE="$DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

    # Tomar la captura
    capture "$FILE"

    # Mostrar diálogo de zenity para elegir dónde guardar el archivo
    NEW_LOCATION=$(zenity --file-selection --save --title="📸 Guardar captura como..." --filename="$FILE")

    # Verificar si el usuario seleccionó una ubicación
    if [ -n "$NEW_LOCATION" ]; then
        # Mover el archivo a la nueva ubicación
        mv "$FILE" "$NEW_LOCATION"
        notify-send "📸 Captura guardada" "$NEW_LOCATION"
        display_image "$NEW_LOCATION"
    else
        # Si el usuario canceló, mantener en la ubicación original
        notify-send "📸 Captura guardada" "$FILE"
        display_image "$FILE"
    fi
    ;;
    
  -i|--install)
    configure_alias
    ;;
    
  -d|--deps)
    check_dependencies
    ;;
    
  -h|--help|"")
    show_help
    ;;
    
  *)
    echo "❌ Opción inválida: $1"
    show_help
    exit 1
    ;;
esac