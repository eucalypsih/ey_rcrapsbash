# 


qc: 
bantu mengintegrasikan **algoritma pemisah otomatis** agar teknik tumpuk dua kotak ini bisa berlaku otomatis pada teks dinamis apa pun (bukan cuma teks error *already exists* ini)

---

aa: 



```rust
        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let current_text = app_state.clone_status.to_text();
            
            // 1. HITUNG BATAS MAKSIMAL LEBAR BERSIH (INNER) YANG TERSEDIA
            let max_allowed_width = area_layar.width.saturating_sub(4); // Kurangi padding luar
            let max_inner_width = max_allowed_width.saturating_sub(2);  // Kurangi border (kiri+kanan)

            // 2. SIMULASI PEMBUNGKUSAN TEKS (Mencari panjang baris terpanjang & jumlah baris)
            let mut max_line_len = 0;
            let mut estimated_lines = 0;
            
            // Pecah berdasarkan kata untuk mensimulasikan Wrap{trim: true} dari Ratatui
            let words: Vec<&str> = current_text.split_whitespace().collect();
            let mut current_line_len = 0;

            for word in words {
                let word_len = word.len();
                
                if current_line_len == 0 {
                    // Kata pertama di baris baru
                    current_line_len = word_len;
                    estimated_lines += 1;
                } else if current_line_len + 1 + word_len <= max_inner_width as usize {
                    // Kata muat di baris yang sama (ditambah 1 spasi)
                    current_line_len += 1 + word_len;
                } else {
                    // Kata tidak muat, buat baris baru
                    if current_line_len > max_line_len {
                        max_line_len = current_line_len;
                    }
                    current_line_len = word_len;
                    estimated_lines += 1;
                }
            }
            if current_line_len > max_line_len {
                max_line_len = current_line_len;
            }
            if estimated_lines == 0 {
                estimated_lines = 1;
            }

            // 3. TENTUKAN DIMENSI DINAMIS AKHIR (RAGGED EDGE)
            // Lebar kotak mengikuti baris terpanjang hasil simulasi, minimal lebar 30
            let dynamic_width = (u16::try_from(max_line_len).unwrap_or(30))
                .max(30) 
                .saturating_add(4); // Tambah 2 untuk border + 2 untuk margin/padding

            // Total tinggi = Jumlah baris tulisan + 2 baris (Garis Borders Atas & Bawah)
            let dynamic_height = estimated_lines as u16 + 2;

            // 4. BANGUN LAYOUT VERTIKAL DAN HORIZONTAL SECARA REAL-TIME
            let layout_vertikal = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(1),                  // Top padding
                    Constraint::Length(dynamic_height),     // Tinggi otomatis pas dengan baris teks
                    Constraint::Min(0),                     // Sisa layar bawah murni kosong
                ]);

            let layout_horizontal = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Length(2),             
                    Constraint::Length(dynamic_width),  // Lebar otomatis menciut pas baris terpanjang
                    Constraint::Min(0),                
                ]);

            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);
            let area_status: Rect = layout_horizontal.split(area_vertikal[1])[1];

            // Render Widget Status Git Clone
            let status_style: Style = app_state.clone_status.to_style();
            let status_text: String = app_state.clone_status.to_text();

            let widget_status = Paragraph::new(status_text)
                .block(Block::default().borders(Borders::ALL).title(" Git Terminal Status "))
                .style(status_style)
                .wrap(Wrap { trim: true }); 

            f.render_widget(widget_status, area_status);
        })?;

```















<br>
