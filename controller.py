#!/usr/bin/env python3
# For Windows and Linux

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import subprocess
import threading
import json
import os
import sys
import time
import hashlib
import struct
import socket
import psutil
import platform
from datetime import datetime
import sqlite3
import zipfile
import xml.etree.ElementTree as ET

class NFCControllerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("NFCman Controller")
        self.root.geometry("1400x900")
        self.root.configure(bg='#1a1a1a')
        self.root.resizable(True, True)
        
        self.devices = {}
        self.current_device = None
        self.scanning = False
        self.reverse_engineering_active = False
        self.system_monitor_active = False
        
        self.setup_styles()
        self.create_menu()
        self.create_layout()
        self.start_device_monitor()
        
    def setup_styles(self):
        style = ttk.Style()
        style.theme_use('clam')
        
        style.configure('Dark.TFrame', background='#1a1a1a')
        style.configure('Dark.TLabel', background='#1a1a1a', foreground='#ffffff')
        style.configure('Dark.TButton', background='#2a2a2a', foreground='#ffffff', borderwidth=1)
        style.configure('Dark.TEntry', background='#2a2a2a', foreground='#ffffff', borderwidth=1)
        style.configure('Dark.TCombobox', background='#2a2a2a', foreground='#ffffff', borderwidth=1)
        style.configure('Dark.Treeview', background='#2a2a2a', foreground='#ffffff', borderwidth=1)
        style.configure('Dark.Treeview.Heading', background='#3a3a3a', foreground='#ffffff', borderwidth=1)
        style.configure('Dark.TNotebook', background='#1a1a1a', borderwidth=0)
        style.configure('Dark.TNotebook.Tab', background='#2a2a2a', foreground='#ffffff', padding=[12, 8])
        style.configure('Dark.Horizontal.TProgressbar', background='#0078d4', borderwidth=0)
        
        style.map('Dark.TButton',
                 background=[('active', '#3a3a3a'), ('pressed', '#4a4a4a')])
        style.map('Dark.TNotebook.Tab',
                 background=[('selected', '#3a3a3a')])
        
    def create_menu(self):
        menubar = tk.Menu(self.root, bg='#2a2a2a', fg='#ffffff', activebackground='#3a3a3a')
        self.root.config(menu=menubar)
        
        file_menu = tk.Menu(menubar, tearoff=0, bg='#2a2a2a', fg='#ffffff', activebackground='#3a3a3a')
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Load Device Profile", command=self.load_device_profile)
        file_menu.add_command(label="Save Device Profile", command=self.save_device_profile)
        file_menu.add_separator()
        file_menu.add_command(label="Export Scan Results", command=self.export_scan_results)
        file_menu.add_command(label="Import Firmware", command=self.import_firmware)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        
        tools_menu = tk.Menu(menubar, tearoff=0, bg='#2a2a2a', fg='#ffffff', activebackground='#3a3a3a')
        menubar.add_cascade(label="Tools", menu=tools_menu)
        tools_menu.add_command(label="ADB Shell", command=self.open_adb_shell)
        tools_menu.add_command(label="Fastboot Mode", command=self.enter_fastboot)
        tools_menu.add_command(label="Recovery Mode", command=self.enter_recovery)
        tools_menu.add_separator()
        tools_menu.add_command(label="Firmware Analyzer", command=self.open_firmware_analyzer)
        tools_menu.add_command(label="Security Profiler", command=self.open_security_profiler)
        
        help_menu = tk.Menu(menubar, tearoff=0, bg='#2a2a2a', fg='#ffffff', activebackground='#3a3a3a')
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="Documentation", command=self.show_documentation)
        help_menu.add_command(label="About", command=self.show_about)
        
    def create_layout(self):
        main_frame = ttk.Frame(self.root, style='Dark.TFrame')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        self.create_toolbar(main_frame)
        self.create_main_content(main_frame)
        self.create_status_bar(main_frame)
        
    def create_toolbar(self, parent):
        toolbar = ttk.Frame(parent, style='Dark.TFrame')
        toolbar.pack(fill=tk.X, pady=(0, 5))
        
        ttk.Label(toolbar, text="Device:", style='Dark.TLabel').pack(side=tk.LEFT, padx=(0, 5))
        
        self.device_combo = ttk.Combobox(toolbar, style='Dark.TCombobox', state="readonly", width=30)
        self.device_combo.pack(side=tk.LEFT, padx=(0, 10))
        self.device_combo.bind('<<ComboboxSelected>>', self.on_device_selected)
        
        ttk.Button(toolbar, text="Refresh Devices", style='Dark.TButton', 
                  command=self.refresh_devices).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(toolbar, text="Connect", style='Dark.TButton', 
                  command=self.connect_device).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(toolbar, text="Disconnect", style='Dark.TButton', 
                  command=self.disconnect_device).pack(side=tk.LEFT, padx=(0, 10))
        
        self.connection_status = ttk.Label(toolbar, text="Status: Disconnected", style='Dark.TLabel')
        self.connection_status.pack(side=tk.RIGHT)
        
    def create_main_content(self, parent):
        content_frame = ttk.Frame(parent, style='Dark.TFrame')
        content_frame.pack(fill=tk.BOTH, expand=True)
        
        paned = ttk.PanedWindow(content_frame, orient=tk.HORIZONTAL)
        paned.pack(fill=tk.BOTH, expand=True)
        
        left_panel = ttk.Frame(paned, style='Dark.TFrame')
        right_panel = ttk.Frame(paned, style='Dark.TFrame')
        
        paned.add(left_panel, weight=1)
        paned.add(right_panel, weight=2)
        
        self.create_left_panel(left_panel)
        self.create_right_panel(right_panel)
        
    def create_left_panel(self, parent):
        notebook = ttk.Notebook(parent, style='Dark.TNotebook')
        notebook.pack(fill=tk.BOTH, expand=True)
        
        self.create_system_tab(notebook)
        self.create_security_tab(notebook)
        self.create_reverse_engineering_tab(notebook)
        self.create_firmware_tab(notebook)
        
    def create_system_tab(self, notebook):
        system_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(system_frame, text="System Monitor")
        
        ttk.Label(system_frame, text="System Overview", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        self.system_tree = ttk.Treeview(system_frame, style='Dark.Treeview', height=15)
        self.system_tree.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        
        self.system_tree['columns'] = ('Size', 'Type', 'Status')
        self.system_tree.column('#0', width=200, minwidth=150)
        self.system_tree.column('Size', width=80, minwidth=60)
        self.system_tree.column('Type', width=100, minwidth=80)
        self.system_tree.column('Status', width=80, minwidth=60)
        
        self.system_tree.heading('#0', text='Component', anchor=tk.W)
        self.system_tree.heading('Size', text='Size', anchor=tk.W)
        self.system_tree.heading('Type', text='Type', anchor=tk.W)
        self.system_tree.heading('Status', text='Status', anchor=tk.W)
        
        system_buttons = ttk.Frame(system_frame, style='Dark.TFrame')
        system_buttons.pack(fill=tk.X, pady=5)
        
        ttk.Button(system_buttons, text="Start Monitor", style='Dark.TButton', 
                  command=self.start_system_monitor).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(system_buttons, text="Stop Monitor", style='Dark.TButton', 
                  command=self.stop_system_monitor).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(system_buttons, text="Export Tree", style='Dark.TButton', 
                  command=self.export_system_tree).pack(side=tk.LEFT)
        
    def create_security_tab(self, notebook):
        security_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(security_frame, text="Security Manager")
        
        ttk.Label(security_frame, text="Security Configuration", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        security_scroll = scrolledtext.ScrolledText(security_frame, height=20, bg='#2a2a2a', fg='#ffffff', 
                                                   insertbackground='#ffffff', selectbackground='#3a3a3a')
        security_scroll.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        self.security_text = security_scroll
        
        security_buttons = ttk.Frame(security_frame, style='Dark.TFrame')
        security_buttons.pack(fill=tk.X, pady=5)
        
        ttk.Button(security_buttons, text="Scan Security", style='Dark.TButton', 
                  command=self.scan_security).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(security_buttons, text="Bypass SELinux", style='Dark.TButton', 
                  command=self.bypass_selinux).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(security_buttons, text="Modify Permissions", style='Dark.TButton', 
                  command=self.modify_permissions).pack(side=tk.LEFT)
        
    def create_reverse_engineering_tab(self, notebook):
        re_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(re_frame, text="Reverse Engineering")
        
        ttk.Label(re_frame, text="Automated Analysis", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        self.re_progress = ttk.Progressbar(re_frame, style='Dark.Horizontal.TProgressbar', mode='indeterminate')
        self.re_progress.pack(fill=tk.X, pady=(0, 10))
        
        self.re_text = scrolledtext.ScrolledText(re_frame, height=18, bg='#2a2a2a', fg='#ffffff', 
                                                insertbackground='#ffffff', selectbackground='#3a3a3a')
        self.re_text.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        
        re_buttons = ttk.Frame(re_frame, style='Dark.TFrame')
        re_buttons.pack(fill=tk.X, pady=5)
        
        ttk.Button(re_buttons, text="Start Analysis", style='Dark.TButton', 
                  command=self.start_reverse_engineering).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(re_buttons, text="Stop Analysis", style='Dark.TButton', 
                  command=self.stop_reverse_engineering).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(re_buttons, text="Generate Report", style='Dark.TButton', 
                  command=self.generate_re_report).pack(side=tk.LEFT)
        
    def create_firmware_tab(self, notebook):
        firmware_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(firmware_frame, text="Firmware Manager")
        
        ttk.Label(firmware_frame, text="NFC Chipset Management", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        chipset_info = ttk.Frame(firmware_frame, style='Dark.TFrame')
        chipset_info.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Label(chipset_info, text="Detected Chipset:", style='Dark.TLabel').grid(row=0, column=0, sticky=tk.W)
        self.chipset_label = ttk.Label(chipset_info, text="Unknown", style='Dark.TLabel', font=('Arial', 10, 'bold'))
        self.chipset_label.grid(row=0, column=1, sticky=tk.W, padx=(10, 0))
        
        ttk.Label(chipset_info, text="Firmware Version:", style='Dark.TLabel').grid(row=1, column=0, sticky=tk.W)
        self.firmware_label = ttk.Label(chipset_info, text="Unknown", style='Dark.TLabel', font=('Arial', 10, 'bold'))
        self.firmware_label.grid(row=1, column=1, sticky=tk.W, padx=(10, 0))
        
        self.firmware_text = scrolledtext.ScrolledText(firmware_frame, height=15, bg='#2a2a2a', fg='#ffffff', 
                                                      insertbackground='#ffffff', selectbackground='#3a3a3a')
        self.firmware_text.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        
        firmware_buttons = ttk.Frame(firmware_frame, style='Dark.TFrame')
        firmware_buttons.pack(fill=tk.X, pady=5)
        
        ttk.Button(firmware_buttons, text="Detect Chipset", style='Dark.TButton', 
                  command=self.detect_chipset).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(firmware_buttons, text="Backup Firmware", style='Dark.TButton', 
                  command=self.backup_firmware).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(firmware_buttons, text="Flash Firmware", style='Dark.TButton', 
                  command=self.flash_firmware).pack(side=tk.LEFT)
        
    def create_right_panel(self, parent):
        right_notebook = ttk.Notebook(parent, style='Dark.TNotebook')
        right_notebook.pack(fill=tk.BOTH, expand=True)
        
        self.create_device_info_tab(right_notebook)
        self.create_apk_manager_tab(right_notebook)
        self.create_scan_results_tab(right_notebook)
        self.create_logs_tab(right_notebook)
        
    def create_device_info_tab(self, notebook):
        info_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(info_frame, text="Device Information")
        
        self.device_info_tree = ttk.Treeview(info_frame, style='Dark.Treeview')
        self.device_info_tree.pack(fill=tk.BOTH, expand=True, pady=(0, 5))
        
        self.device_info_tree['columns'] = ('Value',)
        self.device_info_tree.column('#0', width=200, minwidth=150)
        self.device_info_tree.column('Value', width=300, minwidth=200)
        
        self.device_info_tree.heading('#0', text='Property', anchor=tk.W)
        self.device_info_tree.heading('Value', text='Value', anchor=tk.W)
        
        info_buttons = ttk.Frame(info_frame, style='Dark.TFrame')
        info_buttons.pack(fill=tk.X, pady=5)
        
        ttk.Button(info_buttons, text="Refresh Info", style='Dark.TButton', 
                  command=self.refresh_device_info).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(info_buttons, text="Export Info", style='Dark.TButton', 
                  command=self.export_device_info).pack(side=tk.LEFT)
        
    def create_apk_manager_tab(self, notebook):
        apk_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(apk_frame, text="APK Manager")
        
        ttk.Label(apk_frame, text="APK Installation & Management", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        apk_input_frame = ttk.Frame(apk_frame, style='Dark.TFrame')
        apk_input_frame.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Label(apk_input_frame, text="APK Path:", style='Dark.TLabel').pack(side=tk.LEFT, padx=(0, 5))
        self.apk_path_var = tk.StringVar()
        self.apk_entry = ttk.Entry(apk_input_frame, textvariable=self.apk_path_var, style='Dark.TEntry', width=40)
        self.apk_entry.pack(side=tk.LEFT, padx=(0, 5), fill=tk.X, expand=True)
        ttk.Button(apk_input_frame, text="Browse", style='Dark.TButton', 
                  command=self.browse_apk).pack(side=tk.LEFT)
        
        apk_buttons = ttk.Frame(apk_frame, style='Dark.TFrame')
        apk_buttons.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(apk_buttons, text="Install APK", style='Dark.TButton', 
                  command=self.install_apk).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(apk_buttons, text="Uninstall Package", style='Dark.TButton', 
                  command=self.uninstall_package).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(apk_buttons, text="List Packages", style='Dark.TButton', 
                  command=self.list_packages).pack(side=tk.LEFT)
        
        self.package_list = ttk.Treeview(apk_frame, style='Dark.Treeview')
        self.package_list.pack(fill=tk.BOTH, expand=True)
        
        self.package_list['columns'] = ('Package', 'Version', 'Status')
        self.package_list.column('#0', width=0, stretch=False)
        self.package_list.column('Package', width=300, minwidth=200)
        self.package_list.column('Version', width=100, minwidth=80)
        self.package_list.column('Status', width=100, minwidth=80)
        
        self.package_list.heading('Package', text='Package Name', anchor=tk.W)
        self.package_list.heading('Version', text='Version', anchor=tk.W)
        self.package_list.heading('Status', text='Status', anchor=tk.W)
        
    def create_scan_results_tab(self, notebook):
        scan_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(scan_frame, text="Scan Results")
        
        ttk.Label(scan_frame, text="System Scan Results", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        scan_buttons = ttk.Frame(scan_frame, style='Dark.TFrame')
        scan_buttons.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(scan_buttons, text="Full System Scan", style='Dark.TButton', 
                  command=self.full_system_scan).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(scan_buttons, text="Security Scan", style='Dark.TButton', 
                  command=self.security_scan).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(scan_buttons, text="NFC Scan", style='Dark.TButton', 
                  command=self.nfc_scan).pack(side=tk.LEFT)
        
        self.scan_progress = ttk.Progressbar(scan_frame, style='Dark.Horizontal.TProgressbar', mode='determinate')
        self.scan_progress.pack(fill=tk.X, pady=(0, 10))
        
        self.scan_results = scrolledtext.ScrolledText(scan_frame, bg='#2a2a2a', fg='#ffffff', 
                                                     insertbackground='#ffffff', selectbackground='#3a3a3a')
        self.scan_results.pack(fill=tk.BOTH, expand=True)
        
    def create_logs_tab(self, notebook):
        logs_frame = ttk.Frame(notebook, style='Dark.TFrame')
        notebook.add(logs_frame, text="System Logs")
        
        ttk.Label(logs_frame, text="Real-time System Logs", style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=(0, 10))
        
        log_buttons = ttk.Frame(logs_frame, style='Dark.TFrame')
        log_buttons.pack(fill=tk.X, pady=(0, 10))
        
        ttk.Button(log_buttons, text="Start Logging", style='Dark.TButton', 
                  command=self.start_logging).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(log_buttons, text="Stop Logging", style='Dark.TButton', 
                  command=self.stop_logging).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(log_buttons, text="Clear Logs", style='Dark.TButton', 
                  command=self.clear_logs).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(log_buttons, text="Save Logs", style='Dark.TButton', 
                  command=self.save_logs).pack(side=tk.LEFT)
        
        self.log_text = scrolledtext.ScrolledText(logs_frame, bg='#2a2a2a', fg='#ffffff', 
                                                 insertbackground='#ffffff', selectbackground='#3a3a3a')
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
    def create_status_bar(self, parent):
        status_frame = ttk.Frame(parent, style='Dark.TFrame')
        status_frame.pack(fill=tk.X, pady=(5, 0))
        
        self.status_label = ttk.Label(status_frame, text="Ready", style='Dark.TLabel')
        self.status_label.pack(side=tk.LEFT)
        
        self.progress_bar = ttk.Progressbar(status_frame, style='Dark.Horizontal.TProgressbar', 
                                           mode='indeterminate', length=200)
        self.progress_bar.pack(side=tk.RIGHT, padx=(5, 0))
        
    def start_device_monitor(self):
        def monitor_devices():
            while True:
                try:
                    self.refresh_devices()
                    time.sleep(5)
                except:
                    break
                    
        threading.Thread(target=monitor_devices, daemon=True).start()
        
    def refresh_devices(self):
        try:
            result = subprocess.run(['adb', 'devices'], capture_output=True, text=True, timeout=10)
            devices = []
            
            for line in result.stdout.strip().split('\n')[1:]:
                if line.strip() and '\t' in line:
                    device_id, status = line.strip().split('\t')
                    if status == 'device':
                        devices.append(device_id)
                        
            current_values = list(self.device_combo['values'])
            if set(devices) != set(current_values):
                self.device_combo['values'] = devices
                if devices and not self.device_combo.get():
                    self.device_combo.set(devices[0])
                    
        except subprocess.TimeoutExpired:
            self.log_message("ADB timeout - check USB debugging")
        except FileNotFoundError:
            self.log_message("ADB not found - install Android SDK platform tools")
        except Exception as e:
            self.log_message(f"Device refresh error: {str(e)}")
            
    def on_device_selected(self, event):
        self.current_device = self.device_combo.get()
        if self.current_device:
            self.connection_status.config(text=f"Status: Selected {self.current_device}")
            
    def connect_device(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device selected")
            return
            
        try:
            result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'echo', 'connected'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                self.connection_status.config(text=f"Status: Connected to {self.current_device}")
                self.refresh_device_info()
                self.log_message(f"Connected to device {self.current_device}")
            else:
                raise Exception("Connection failed")
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to connect: {str(e)}")
            
    def disconnect_device(self):
        self.current_device = None
        self.connection_status.config(text="Status: Disconnected")
        self.device_info_tree.delete(*self.device_info_tree.get_children())
        self.log_message("Attemptiing disconnection from device")
        
    def refresh_device_info(self):
        if not self.current_device:
            return
            
        self.device_info_tree.delete(*self.device_info_tree.get_children())
        
        device_props = {
            'Device Model': 'ro.product.model',
            'Android Version': 'ro.build.version.release',
            'SDK Level': 'ro.build.version.sdk',
            'Manufacturer': 'ro.product.manufacturer',
            'Brand': 'ro.product.brand',
            'CPU Architecture': 'ro.product.cpu.abi',
            'Build ID': 'ro.build.id',
            'Security Patch': 'ro.build.version.security_patch',
            'Bootloader': 'ro.bootloader',
            'Hardware': 'ro.hardware',
            'Serial Number': 'ro.serialno'
        }
        
        for display_name, prop in device_props.items():
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', prop], 
                                      capture_output=True, text=True, timeout=5)
                value = result.stdout.strip() or "Unknown"
                self.device_info_tree.insert('', 'end', text=display_name, values=(value,))
            except:
                self.device_info_tree.insert('', 'end', text=display_name, values=("Error",))
                
    def start_system_monitor(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        self.system_monitor_active = True
        self.update_status("Starting system monitor...")
        
        def monitor_system():
            self.system_tree.delete(*self.system_tree.get_children())
            
            try:
                storage_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'df', '-h'], 
                                              capture_output=True, text=True, timeout=10)
                
                storage_root = self.system_tree.insert('', 'end', text='Storage', values=('', 'Category', 'Active'))
                
                for line in storage_result.stdout.strip().split('\n')[1:]:
                    parts = line.split()
                    if len(parts) >= 6:
                        filesystem = parts[0]
                        size = parts[1]
                        used = parts[2]
                        available = parts[3]
                        use_percent = parts[4]
                        mountpoint = parts[5]
                        
                        self.system_tree.insert(storage_root, 'end', 
                                              text=f"{mountpoint} ({filesystem})",
                                              values=(f"{used}/{size}", 'Filesystem', use_percent))
                
                process_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'ps'], 
                                              capture_output=True, text=True, timeout=10)
                
                process_root = self.system_tree.insert('', 'end', text='Processes', values=('', 'Category', 'Active'))
                
                process_count = 0
                for line in process_result.stdout.strip().split('\n')[1:]:
                    if process_count >= 20:
                        break
                    parts = line.split()
                    if len(parts) >= 9:
                        pid = parts[1]
                        process_name = parts[8]
                        
                        self.system_tree.insert(process_root, 'end', 
                                              text=f"{process_name} (PID: {pid})",
                                              values=('', 'Process', 'Running'))
                        process_count += 1
                
                packages_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'pm', 'list', 'packages'], 
                                                capture_output=True, text=True, timeout=15)
                
                packages_root = self.system_tree.insert('', 'end', text='Installed Packages', values=('', 'Category', 'Active'))
                
                package_count = 0
                for line in packages_result.stdout.strip().split('\n'):
                    if package_count >= 50:
                        break
                    if line.startswith('package:'):
                        package_name = line.replace('package:', '').strip()
                        self.system_tree.insert(packages_root, 'end', 
                                              text=package_name,
                                              values=('', 'Package', 'Installed'))
                        package_count += 1
                
                self.system_tree.item(storage_root, open=True)
                self.system_tree.item(process_root, open=True)
                self.system_tree.item(packages_root, open=True)
                
                self.update_status("System monitor completed")
                
            except Exception as e:
                self.log_message(f"System monitor error: {str(e)}")
                self.update_status("System monitor failed")
                
        threading.Thread(target=monitor_system, daemon=True).start()
        
    def stop_system_monitor(self):
        self.system_monitor_active = False
        self.update_status("System monitor stopped")
        
    def export_system_tree(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                data = self.tree_to_dict(self.system_tree)
                with open(filename, 'w') as f:
                    json.dump(data, f, indent=2)
                messagebox.showinfo("Success", f"System tree exported to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Export failed: {str(e)}")
                
    def tree_to_dict(self, tree):
        def item_to_dict(item):
            children = tree.get_children(item)
            result = {
                'text': tree.item(item, 'text'),
                'values': tree.item(item, 'values'),
                'children': [item_to_dict(child) for child in children]
            }
            return result
            
        root_items = tree.get_children('')
        return [item_to_dict(item) for item in root_items]
        
    def scan_security(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        self.security_text.delete(1.0, tk.END)
        self.security_text.insert(tk.END, "Starting security scan...\n\n")
        
        def security_scan():
            try:
                self.security_text.insert(tk.END, "Checking SELinux status...\n")
                selinux_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getenforce'], 
                                              capture_output=True, text=True, timeout=10)
                self.security_text.insert(tk.END, f"SELinux: {selinux_result.stdout.strip()}\n\n")
                
                self.security_text.insert(tk.END, "Checking root access...\n")
                root_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'su', '-c', 'id'], 
                                           capture_output=True, text=True, timeout=10)
                if root_result.returncode == 0:
                    self.security_text.insert(tk.END, f"Root access: Available\n{root_result.stdout}\n\n")
                else:
                    self.security_text.insert(tk.END, "Root access: Not available\n\n")
                
                self.security_text.insert(tk.END, "Checking security patch level...\n")
                patch_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', 'ro.build.version.security_patch'], 
                                            capture_output=True, text=True, timeout=5)
                self.security_text.insert(tk.END, f"Security patch: {patch_result.stdout.strip()}\n\n")
                
                self.security_text.insert(tk.END, "Checking dm-verity status...\n")
                verity_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', 'ro.boot.veritymode'], 
                                             capture_output=True, text=True, timeout=5)
                self.security_text.insert(tk.END, f"Dm-verity: {verity_result.stdout.strip()}\n\n")
                
                self.security_text.insert(tk.END, "Checking bootloader status...\n")
                bootloader_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', 'ro.boot.verifiedbootstate'], 
                                                  capture_output=True, text=True, timeout=5)
                self.security_text.insert(tk.END, f"Verified boot: {bootloader_result.stdout.strip()}\n\n")
                
                self.security_text.insert(tk.END, "Security scan completed.\n")
                
            except Exception as e:
                self.security_text.insert(tk.END, f"Security scan error: {str(e)}\n")
                
        threading.Thread(target=security_scan, daemon=True).start()
        
    def bypass_selinux(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        result = messagebox.askyesno("Warning", 
                                   "This will attempt to modify SELinux settings. This could potentially damage your device. Continue?")
        if not result:
            return
            
        def bypass():
            try:
                self.security_text.insert(tk.END, "\nAttempting SELinux bypass...\n")
                
                commands = [
                    'su -c "setenforce 0"',
                    'su -c "echo 0 > /sys/fs/selinux/enforce"',
                    'su -c "mount -o rw,remount /system"'
                ]
                
                for cmd in commands:
                    result = subprocess.run(['adb', '-s', self.current_device, 'shell', cmd], 
                                          capture_output=True, text=True, timeout=10)
                    self.security_text.insert(tk.END, f"Command: {cmd}\n")
                    self.security_text.insert(tk.END, f"Result: {result.returncode}\n")
                    if result.stdout:
                        self.security_text.insert(tk.END, f"Output: {result.stdout}\n")
                    self.security_text.insert(tk.END, "\n")
                
                self.security_text.insert(tk.END, "SELinux bypass attempt completed.\n")
                
            except Exception as e:
                self.security_text.insert(tk.END, f"SELinux bypass error: {str(e)}\n")
                
        threading.Thread(target=bypass, daemon=True).start()
        
    def modify_permissions(self):
        permission_window = tk.Toplevel(self.root)
        permission_window.title("Permission Manager")
        permission_window.geometry("600x400")
        permission_window.configure(bg='#1a1a1a')
        
        ttk.Label(permission_window, text="Permission Modification", style='Dark.TLabel', 
                 font=('Arial', 12, 'bold')).pack(pady=10)
        
        perm_frame = ttk.Frame(permission_window, style='Dark.TFrame')
        perm_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        ttk.Label(perm_frame, text="Package:", style='Dark.TLabel').grid(row=0, column=0, sticky=tk.W, pady=5)
        package_entry = ttk.Entry(perm_frame, style='Dark.TEntry', width=40)
        package_entry.grid(row=0, column=1, sticky=tk.W, padx=(10, 0), pady=5)
        
        ttk.Label(perm_frame, text="Permission:", style='Dark.TLabel').grid(row=1, column=0, sticky=tk.W, pady=5)
        permission_entry = ttk.Entry(perm_frame, style='Dark.TEntry', width=40)
        permission_entry.grid(row=1, column=1, sticky=tk.W, padx=(10, 0), pady=5)
        
        button_frame = ttk.Frame(perm_frame, style='Dark.TFrame')
        button_frame.grid(row=2, column=0, columnspan=2, pady=20)
        
        def grant_permission():
            package = package_entry.get()
            permission = permission_entry.get()
            if package and permission:
                try:
                    result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'pm', 'grant', package, permission], 
                                          capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        messagebox.showinfo("Success", f"Permission granted to {package}")
                    else:
                        messagebox.showerror("Error", f"Failed to grant permission: {result.stderr}")
                except Exception as e:
                    messagebox.showerror("Error", f"Permission error: {str(e)}")
                    
        def revoke_permission():
            package = package_entry.get()
            permission = permission_entry.get()
            if package and permission:
                try:
                    result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'pm', 'revoke', package, permission], 
                                          capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        messagebox.showinfo("Success", f"Permission revoked from {package}")
                    else:
                        messagebox.showerror("Error", f"Failed to revoke permission: {result.stderr}")
                except Exception as e:
                    messagebox.showerror("Error", f"Permission error: {str(e)}")
        
        ttk.Button(button_frame, text="Grant Permission", style='Dark.TButton', 
                  command=grant_permission).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Revoke Permission", style='Dark.TButton', 
                  command=revoke_permission).pack(side=tk.LEFT, padx=5)
        
    def start_reverse_engineering(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        self.reverse_engineering_active = True
        self.re_progress.start()
        self.re_text.delete(1.0, tk.END)
        self.re_text.insert(tk.END, "Starting automated reverse engineering analysis...\n\n")
        
        def reverse_engineer():
            try:
                stages = [
                    ("Binary Analysis", self.analyze_binaries),
                    ("Memory Mapping", self.analyze_memory),
                    ("System Call Tracing", self.trace_syscalls),
                    ("NFC Stack Analysis", self.analyze_nfc_stack),
                    ("Security Implementation Scan", self.scan_security_implementations),
                    ("Firmware Extraction", self.extract_firmware),
                    ("Vulnerability Assessment", self.assess_vulnerabilities)
                ]
                
                total_stages = len(stages)
                for i, (stage_name, stage_func) in enumerate(stages):
                    if not self.reverse_engineering_active:
                        break
                        
                    self.re_text.insert(tk.END, f"Stage {i+1}/{total_stages}: {stage_name}\n")
                    self.re_text.insert(tk.END, "=" * 50 + "\n")
                    
                    stage_func()
                    
                    self.re_text.insert(tk.END, f"\nStage {i+1} completed.\n\n")
                    time.sleep(1)
                
                if self.reverse_engineering_active:
                    self.re_text.insert(tk.END, "Reverse engineering analysis completed successfully.\n")
                else:
                    self.re_text.insert(tk.END, "Reverse engineering analysis stopped by user.\n")
                    
            except Exception as e:
                self.re_text.insert(tk.END, f"Reverse engineering error: {str(e)}\n")
            finally:
                self.re_progress.stop()
                self.reverse_engineering_active = False
                
        threading.Thread(target=reverse_engineer, daemon=True).start()
        
    def stop_reverse_engineering(self):
        self.reverse_engineering_active = False
        self.re_progress.stop()
        self.re_text.insert(tk.END, "\nStopping reverse engineering analysis...\n")
        
    def analyze_binaries(self):
        self.re_text.insert(tk.END, "Analyzing system binaries...\n")
        
        binaries_to_analyze = [
            '/system/bin/nfc',
            '/system/lib/libnfc-nci.so',
            '/system/lib/hw/nfc_nci.*.so',
            '/vendor/lib/libpn*.so',
            '/system/bin/se_nq_extn_client'
        ]
        
        for binary in binaries_to_analyze:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'ls', '-la', binary], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    self.re_text.insert(tk.END, f"Found: {binary}\n")
                    
                    file_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'file', binary], 
                                                capture_output=True, text=True, timeout=5)
                    if file_result.returncode == 0:
                        self.re_text.insert(tk.END, f"  Type: {file_result.stdout.strip()}\n")
                        
                    size_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'stat', '-c', '%s', binary], 
                                                capture_output=True, text=True, timeout=5)
                    if size_result.returncode == 0:
                        size = int(size_result.stdout.strip())
                        self.re_text.insert(tk.END, f"  Size: {size} bytes\n")
                        
            except Exception as e:
                self.re_text.insert(tk.END, f"Error analyzing {binary}: {str(e)}\n")
                
    def analyze_memory(self):
        self.re_text.insert(tk.END, "Analyzing memory mappings...\n")
        
        try:
            maps_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'cat', '/proc/1/maps'], 
                                       capture_output=True, text=True, timeout=10)
            if maps_result.returncode == 0:
                lines = maps_result.stdout.strip().split('\n')
                nfc_related = [line for line in lines if 'nfc' in line.lower()]
                
                self.re_text.insert(tk.END, f"Found {len(nfc_related)} NFC-related memory mappings:\n")
                for mapping in nfc_related[:10]:
                    self.re_text.insert(tk.END, f"  {mapping}\n")
                    
        except Exception as e:
            self.re_text.insert(tk.END, f"Memory analysis error: {str(e)}\n")
            
    def trace_syscalls(self):
        self.re_text.insert(tk.END, "Tracing system calls...\n")
        
        try:
            strace_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'ps', '|', 'grep', 'nfc'], 
                                         capture_output=True, text=True, timeout=10)
            if strace_result.returncode == 0:
                self.re_text.insert(tk.END, "NFC processes found:\n")
                for line in strace_result.stdout.strip().split('\n'):
                    if line.strip():
                        self.re_text.insert(tk.END, f"  {line}\n")
            else:
                self.re_text.insert(tk.END, "No NFC processes currently running.\n")
                
        except Exception as e:
            self.re_text.insert(tk.END, f"Syscall tracing error: {str(e)}\n")
            
    def analyze_nfc_stack(self):
        self.re_text.insert(tk.END, "Analyzing NFC stack implementation...\n")
        
        nfc_components = [
            '/sys/class/nfc',
            '/dev/nfc*',
            '/proc/nfc',
            '/sys/kernel/debug/nfc',
            '/data/vendor/nfc'
        ]
        
        for component in nfc_components:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'ls', '-la', component], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    self.re_text.insert(tk.END, f"NFC component found: {component}\n")
                    self.re_text.insert(tk.END, f"  {result.stdout.strip()}\n")
                    
            except Exception as e:
                self.re_text.insert(tk.END, f"Error checking {component}: {str(e)}\n")
                
    def scan_security_implementations(self):
        self.re_text.insert(tk.END, "Scanning security implementations...\n")
        
        security_checks = [
            ('SELinux policies', 'ls /sepolicy'),
            ('Security contexts', 'ls -Z /system/bin/nfc*'),
            ('Capabilities', 'getcap /system/bin/nfc*'),
            ('Permissions', 'ls -la /dev/nfc*'),
            ('Group memberships', 'groups nfc')
        ]
        
        for check_name, command in security_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=5)
                self.re_text.insert(tk.END, f"{check_name}:\n")
                if result.returncode == 0:
                    self.re_text.insert(tk.END, f"  {result.stdout.strip()}\n")
                else:
                    self.re_text.insert(tk.END, f"  Not accessible or not found\n")
                    
            except Exception as e:
                self.re_text.insert(tk.END, f"  Error: {str(e)}\n")
                
    def extract_firmware(self):
        self.re_text.insert(tk.END, "Attempting firmware extraction...\n")
        
        firmware_locations = [
            '/vendor/firmware/nfc*',
            '/system/etc/firmware/nfc*',
            '/firmware/image/nfc*',
            '/data/vendor/firmware/nfc*'
        ]
        
        for location in firmware_locations:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'find', location.split('*')[0], '-name', '*nfc*'], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0 and result.stdout.strip():
                    self.re_text.insert(tk.END, f"Firmware files found in {location}:\n")
                    for file in result.stdout.strip().split('\n'):
                        if file.strip():
                            self.re_text.insert(tk.END, f"  {file}\n")
                            
            except Exception as e:
                self.re_text.insert(tk.END, f"Error scanning {location}: {str(e)}\n")
                
    def assess_vulnerabilities(self):
        self.re_text.insert(tk.END, "Assessing potential vulnerabilities...\n")
        
        vulnerability_checks = [
            ('Writable system directories', 'find /system -type d -perm -002'),
            ('SUID binaries', 'find /system -perm -4000'),
            ('World-writable files', 'find /data -perm -002 -type f'),
            ('Unprotected sockets', 'netstat -an | grep LISTEN'),
            ('Debug interfaces', 'ls /sys/kernel/debug/')
        ]
        
        for check_name, command in vulnerability_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=15)
                self.re_text.insert(tk.END, f"{check_name}:\n")
                if result.returncode == 0:
                    # Fix: Extract the newline split operation outside the f-string
                    output_lines = result.stdout.strip().split('\n')
                    lines = output_lines[:5]
                    for line in lines:
                        if line.strip():
                            self.re_text.insert(tk.END, f"  {line}\n")
                    if len(output_lines) > 5:
                        remaining_count = len(output_lines) - 5
                        self.re_text.insert(tk.END, f"  ... and {remaining_count} more\n")
                else:
                    self.re_text.insert(tk.END, f"  No results or access denied\n")
                    
            except Exception as e:
                self.re_text.insert(tk.END, f"  Error: {str(e)}\n")
                
    def generate_re_report(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                content = self.re_text.get(1.0, tk.END)
                with open(filename, 'w') as f:
                    f.write(f"NFCman Reverse Engineering Report\n")
                    f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write(f"Device: {self.current_device}\n")
                    f.write("=" * 50 + "\n\n")
                    f.write(content)
                messagebox.showinfo("Success", f"Report saved to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save report: {str(e)}")
                
    def detect_chipset(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        self.firmware_text.delete(1.0, tk.END)
        self.firmware_text.insert(tk.END, "Detecting NFC chipset...\n\n")
        
        def detect():
            try:
                chip_id_locations = [
                    '/sys/class/nfc/nfc*/device/chip_id',
                    '/proc/nfc/chip_id',
                    '/sys/kernel/debug/nfc/chip_info'
                ]
                
                chipset_detected = False
                for location in chip_id_locations:
                    try:
                        result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'cat', location], 
                                              capture_output=True, text=True, timeout=5)
                        if result.returncode == 0:
                            chip_id = result.stdout.strip()
                            self.firmware_text.insert(tk.END, f"Chip ID found at {location}: {chip_id}\n")
                            
                            chipset_mapping = {
                                '0x544C': 'NXP PN544',
                                '0x547C': 'NXP PN547',
                                '0x548C': 'NXP PN548',
                                '0x2079': 'Broadcom BCM20791',
                                '0x2080': 'Broadcom BCM20795',
                                '0x6595': 'Qualcomm QCA6595'
                            }
                            
                            chipset = chipset_mapping.get(chip_id, f"Unknown chipset (ID: {chip_id})")
                            self.chipset_label.config(text=chipset)
                            self.firmware_text.insert(tk.END, f"Detected chipset: {chipset}\n\n")
                            chipset_detected = True
                            break
                            
                    except:
                        continue
                
                if not chipset_detected:
                    hardware_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', 'ro.hardware'], 
                                                   capture_output=True, text=True, timeout=5)
                    if hardware_result.returncode == 0:
                        hardware = hardware_result.stdout.strip().lower()
                        if 'pn5' in hardware:
                            chipset = 'NXP PN5XX Series'
                        elif 'bcm' in hardware:
                            chipset = 'Broadcom BCM Series'
                        elif 'qca' in hardware:
                            chipset = 'Qualcomm QCA Series'
                        else:
                            chipset = f'Unknown ({hardware})'
                            
                        self.chipset_label.config(text=chipset)
                        self.firmware_text.insert(tk.END, f"Chipset inferred from hardware: {chipset}\n\n")
                
                firmware_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'cat', '/sys/class/nfc/nfc*/device/firmware_version'], 
                                               capture_output=True, text=True, timeout=5)
                if firmware_result.returncode == 0:
                    firmware_version = firmware_result.stdout.strip()
                    self.firmware_label.config(text=firmware_version)
                    self.firmware_text.insert(tk.END, f"Firmware version: {firmware_version}\n")
                else:
                    self.firmware_label.config(text="Unknown")
                    self.firmware_text.insert(tk.END, "Firmware version: Unable to determine\n")
                
                self.firmware_text.insert(tk.END, "\nChipset detection completed.\n")
                
            except Exception as e:
                self.firmware_text.insert(tk.END, f"Chipset detection error: {str(e)}\n")
                
        threading.Thread(target=detect, daemon=True).start()
        
    def backup_firmware(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        filename = filedialog.asksaveasfilename(
            defaultextension=".bin",
            filetypes=[("Binary files", "*.bin"), ("All files", "*.*")]
        )
        
        if filename:
            def backup():
                try:
                    self.firmware_text.insert(tk.END, f"\nBacking up firmware to {filename}...\n")
                    
                    firmware_partitions = [
                        '/dev/block/bootdevice/by-name/nfc',
                        '/dev/block/platform/*/by-name/nfc_fw',
                        '/vendor/firmware/nfc.bin'
                    ]
                    
                    backup_successful = False
                    for partition in firmware_partitions:
                        try:
                            result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'su', '-c', f'dd if={partition} bs=1024'], 
                                                  capture_output=True, timeout=30)
                            if result.returncode == 0 and len(result.stdout) > 0:
                                with open(filename, 'wb') as f:
                                    f.write(result.stdout)
                                self.firmware_text.insert(tk.END, f"Firmware backup successful from {partition}\n")
                                self.firmware_text.insert(tk.END, f"Backup size: {len(result.stdout)} bytes\n")
                                backup_successful = True
                                break
                        except:
                            continue
                    
                    if not backup_successful:
                        self.firmware_text.insert(tk.END, "Unable to backup firmware - partition not found or access denied\n")
                        
                except Exception as e:
                    self.firmware_text.insert(tk.END, f"Firmware backup error: {str(e)}\n")
                    
            threading.Thread(target=backup, daemon=True).start()
            
    def flash_firmware(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        result = messagebox.askyesno("Critical Warning", 
                                   "Flashing firmware can permanently damage your device and void warranties. "
                                   "This operation requires root access and may brick your device. "
                                   "Do you want to continue?")
        if not result:
            return
            
        filename = filedialog.askopenfilename(
            filetypes=[("Binary files", "*.bin"), ("All files", "*.*")]
        )
        
        if filename:
            def flash():
                try:
                    self.firmware_text.insert(tk.END, f"\nFlashing firmware from {filename}...\n")
                    
                    with open(filename, 'rb') as f:
                        firmware_data = f.read()
                    
                    self.firmware_text.insert(tk.END, f"Firmware size: {len(firmware_data)} bytes\n")
                    
                    checksum = hashlib.md5(firmware_data).hexdigest()
                    self.firmware_text.insert(tk.END, f"Firmware checksum: {checksum}\n")
                    
                    temp_path = '/data/local/tmp/custom_firmware.bin'
                    
                    upload_result = subprocess.run(['adb', '-s', self.current_device, 'push', filename, temp_path], 
                                                 capture_output=True, text=True, timeout=60)
                    if upload_result.returncode != 0:
                        raise Exception(f"Upload failed: {upload_result.stderr}")
                    
                    self.firmware_text.insert(tk.END, "Firmware uploaded to device\n")
                    
                    flash_commands = [
                        f'su -c "chmod 644 {temp_path}"',
                        f'su -c "dd if={temp_path} of=/dev/block/bootdevice/by-name/nfc bs=1024"',
                        'su -c "sync"',
                        f'su -c "rm {temp_path}"'
                    ]
                    
                    for cmd in flash_commands:
                        result = subprocess.run(['adb', '-s', self.current_device, 'shell', cmd], 
                                              capture_output=True, text=True, timeout=30)
                        self.firmware_text.insert(tk.END, f"Command: {cmd}\n")
                        self.firmware_text.insert(tk.END, f"Result: {result.returncode}\n")
                        if result.stdout:
                            self.firmware_text.insert(tk.END, f"Output: {result.stdout}\n")
                        if result.stderr:
                            self.firmware_text.insert(tk.END, f"Error: {result.stderr}\n")
                        self.firmware_text.insert(tk.END, "\n")
                    
                    self.firmware_text.insert(tk.END, "Firmware flashing completed. Reboot device to activate.\n")
                    
                except Exception as e:
                    self.firmware_text.insert(tk.END, f"Firmware flashing error: {str(e)}\n")
                    
            threading.Thread(target=flash, daemon=True).start()
            
    def browse_apk(self):
        filename = filedialog.askopenfilename(
            filetypes=[("APK files", "*.apk"), ("All files", "*.*")]
        )
        if filename:
            self.apk_path_var.set(filename)
            
    def install_apk(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        apk_path = self.apk_path_var.get()
        if not apk_path:
            messagebox.showwarning("Warning", "No APK file selected")
            return
            
        def install():
            try:
                self.update_status("Installing APK...")
                result = subprocess.run(['adb', '-s', self.current_device, 'install', '-r', apk_path], 
                                      capture_output=True, text=True, timeout=120)
                
                if result.returncode == 0:
                    messagebox.showinfo("Success", "APK installed successfully")
                    self.list_packages()
                else:
                    messagebox.showerror("Error", f"Installation failed: {result.stderr}")
                    
            except Exception as e:
                messagebox.showerror("Error", f"Installation error: {str(e)}")
            finally:
                self.update_status("Ready")
                
        threading.Thread(target=install, daemon=True).start()
        
    def uninstall_package(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        selection = self.package_list.selection()
        if not selection:
            messagebox.showwarning("Warning", "No package selected")
            return
            
        package_name = self.package_list.item(selection[0])['values'][0]
        
        result = messagebox.askyesno("Confirm", f"Uninstall package {package_name}?")
        if result:
            def uninstall():
                try:
                    self.update_status("Uninstalling package...")
                    result = subprocess.run(['adb', '-s', self.current_device, 'uninstall', package_name], 
                                          capture_output=True, text=True, timeout=60)
                    
                    if result.returncode == 0:
                        messagebox.showinfo("Success", f"Package {package_name} uninstalled")
                        self.list_packages()
                    else:
                        messagebox.showerror("Error", f"Uninstall failed: {result.stderr}")
                        
                except Exception as e:
                    messagebox.showerror("Error", f"Uninstall error: {str(e)}")
                finally:
                    self.update_status("Ready")
                    
            threading.Thread(target=uninstall, daemon=True).start()
            
    def list_packages(self):
        if not self.current_device:
            return
            
        def list_apps():
            try:
                self.package_list.delete(*self.package_list.get_children())
                
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'pm', 'list', 'packages', '-3'], 
                                      capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    for line in result.stdout.strip().split('\n'):
                        if line.startswith('package:'):
                            package_name = line.replace('package:', '').strip()
                            
                            version_result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'dumpsys', 'package', package_name, '|', 'grep', 'versionName'], 
                                                          capture_output=True, text=True, timeout=5)
                            version = "Unknown"
                            if version_result.returncode == 0:
                                for version_line in version_result.stdout.split('\n'):
                                    if 'versionName=' in version_line:
                                        version = version_line.split('versionName=')[1].strip()
                                        break
                            
                            self.package_list.insert('', 'end', values=(package_name, version, "Installed"))
                            
            except Exception as e:
                self.log_message(f"Package listing error: {str(e)}")
                
        threading.Thread(target=list_apps, daemon=True).start()
        
    def full_system_scan(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        self.scan_results.delete(1.0, tk.END)
        self.scan_progress['value'] = 0
        
        def scan():
            try:
                scan_stages = [
                    ("System Information", self.scan_system_info),
                    ("Hardware Analysis", self.scan_hardware),
                    ("Security Assessment", self.scan_security_full),
                    ("Network Configuration", self.scan_network),
                    ("Storage Analysis", self.scan_storage),
                    ("Process Analysis", self.scan_processes),
                    ("NFC Subsystem", self.scan_nfc_subsystem)
                ]
                
                total_stages = len(scan_stages)
                for i, (stage_name, stage_func) in enumerate(scan_stages):
                    self.scan_results.insert(tk.END, f"\n{'='*50}\n")
                    self.scan_results.insert(tk.END, f"Stage {i+1}/{total_stages}: {stage_name}\n")
                    self.scan_results.insert(tk.END, f"{'='*50}\n")
                    
                    stage_func()
                    
                    progress = ((i + 1) / total_stages) * 100
                    self.scan_progress['value'] = progress
                    
                self.scan_results.insert(tk.END, f"\n{'='*50}\n")
                self.scan_results.insert(tk.END, "Full system scan completed.\n")
                
            except Exception as e:
                self.scan_results.insert(tk.END, f"System scan error: {str(e)}\n")
                
        threading.Thread(target=scan, daemon=True).start()
        
    def scan_system_info(self):
        system_props = [
            ('Android Version', 'ro.build.version.release'),
            ('Security Patch', 'ro.build.version.security_patch'),
            ('Kernel Version', 'sys.kernel.version'),
            ('CPU Architecture', 'ro.product.cpu.abi'),
            ('Total RAM', 'ro.config.total_ram'),
            ('Build Type', 'ro.build.type'),
            ('Bootloader', 'ro.bootloader'),
            ('Baseband', 'gsm.version.baseband')
        ]
        
        for prop_name, prop_key in system_props:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'getprop', prop_key], 
                                      capture_output=True, text=True, timeout=5)
                value = result.stdout.strip() if result.returncode == 0 else "Unknown"
                self.scan_results.insert(tk.END, f"{prop_name}: {value}\n")
            except:
                self.scan_results.insert(tk.END, f"{prop_name}: Error\n")
                
    def scan_hardware(self):
        hardware_checks = [
            ('CPU Info', 'cat /proc/cpuinfo | head -20'),
            ('Memory Info', 'cat /proc/meminfo | head -10'),
            ('Hardware Features', 'pm list features | grep hardware'),
            ('Block Devices', 'ls -la /dev/block/ | head -10'),
            ('NFC Hardware', 'ls -la /dev/nfc* /sys/class/nfc/')
        ]
        
        for check_name, command in hardware_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=10)
                self.scan_results.insert(tk.END, f"\n{check_name}:\n")
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')[:10]
                    for line in lines:
                        self.scan_results.insert(tk.END, f"  {line}\n")
                else:
                    self.scan_results.insert(tk.END, "  Not accessible\n")
            except:
                self.scan_results.insert(tk.END, f"\n{check_name}: Error\n")
                
    def scan_security_full(self):
        security_checks = [
            ('SELinux Status', 'getenforce'),
            ('Root Access', 'su -c id'),
            ('Encryption Status', 'getprop ro.crypto.state'),
            ('Verified Boot', 'getprop ro.boot.verifiedbootstate'),
            ('Security Services', 'ps | grep security'),
            ('Permission Policies', 'ls /sepolicy*')
        ]
        
        for check_name, command in security_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=5)
                self.scan_results.insert(tk.END, f"\n{check_name}:\n")
                if result.returncode == 0:
                    self.scan_results.insert(tk.END, f"  {result.stdout.strip()}\n")
                else:
                    self.scan_results.insert(tk.END, "  Access denied or not found\n")
            except:
                self.scan_results.insert(tk.END, f"\n{check_name}: Error\n")
                
    def scan_network(self):
        network_checks = [
            ('Network Interfaces', 'ip addr show'),
            ('Routing Table', 'ip route'),
            ('DNS Configuration', 'getprop | grep dns'),
            ('WiFi State', 'dumpsys wifi | grep "Wi-Fi is"'),
            ('Bluetooth State', 'dumpsys bluetooth_manager | grep enabled')
        ]
        
        for check_name, command in network_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=10)
                self.scan_results.insert(tk.END, f"\n{check_name}:\n")
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')[:5]
                    for line in lines:
                        self.scan_results.insert(tk.END, f"  {line}\n")
                else:
                    self.scan_results.insert(tk.END, "  Not accessible\n")
            except:
                self.scan_results.insert(tk.END, f"\n{check_name}: Error\n")
                
    def scan_storage(self):
        storage_checks = [
            ('Disk Usage', 'df -h'),
            ('Mount Points', 'mount | head -10'),
            ('Partition Table', 'cat /proc/partitions'),
            ('Storage Devices', 'ls -la /dev/block/sd*')
        ]
        
        for check_name, command in storage_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=10)
                self.scan_results.insert(tk.END, f"\n{check_name}:\n")
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')[:8]
                    for line in lines:
                        self.scan_results.insert(tk.END, f"  {line}\n")
                else:
                    self.scan_results.insert(tk.END, "  Not accessible\n")
            except:
                self.scan_results.insert(tk.END, f"\n{check_name}: Error\n")
                
    def scan_processes(self):
        try:
            result = subprocess.run(['adb', '-s', self.current_device, 'shell', 'ps', '-A'], 
                                  capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                # Fix: Extract the newline split operation outside the f-string
                output_lines = result.stdout.strip().split('\n')
                total_processes = len(output_lines) - 1
                self.scan_results.insert(tk.END, f"\nRunning Processes ({total_processes} total):\n")
                
                critical_processes = []
                for line in output_lines[1:]:
                    if any(keyword in line.lower() for keyword in ['system', 'nfc', 'security', 'crypto', 'boot']):
                        critical_processes.append(line)
                
                for process in critical_processes[:15]:
                    self.scan_results.insert(tk.END, f"  {process}\n")
                    
            else:
                self.scan_results.insert(tk.END, "\nProcess scan: Access denied\n")
        except:
            self.scan_results.insert(tk.END, "\nProcess scan: Error\n")
            
    def scan_nfc_subsystem(self):
        nfc_checks = [
            ('NFC Service Status', 'dumpsys nfc | head -20'),
            ('NFC Hardware State', 'cat /sys/class/nfc/nfc*/device/state'),
            ('NFC Firmware Version', 'cat /sys/class/nfc/nfc*/device/firmware_version'),
            ('NFC Device Nodes', 'ls -la /dev/nfc*'),
            ('NFC Libraries', 'find /system -name "*nfc*" -type f'),
            ('NFC Configuration', 'find /vendor -name "*nfc*" -name "*.conf"')
        ]
        
        for check_name, command in nfc_checks:
            try:
                result = subprocess.run(['adb', '-s', self.current_device, 'shell', command], 
                                      capture_output=True, text=True, timeout=10)
                self.scan_results.insert(tk.END, f"\n{check_name}:\n")
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')[:10]
                    for line in lines:
                        if line.strip():
                            self.scan_results.insert(tk.END, f"  {line}\n")
                else:
                    self.scan_results.insert(tk.END, "  Not found or access denied\n")
            except:
                self.scan_results.insert(tk.END, f"\n{check_name}: Error\n")
                
    def security_scan(self):
        self.scan_security()
        
    def nfc_scan(self):
        self.scan_nfc_subsystem()
        
    def start_logging(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        def log_monitor():
            try:
                process = subprocess.Popen(['adb', '-s', self.current_device, 'logcat', '-v', 'threadtime'], 
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
                                         universal_newlines=True, bufsize=1)
                
                while process.poll() is None:
                    line = process.stdout.readline()
                    if line:
                        timestamp = datetime.now().strftime('%H:%M:%S')
                        self.log_text.insert(tk.END, f"[{timestamp}] {line}")
                        self.log_text.see(tk.END)
                        
            except Exception as e:
                self.log_text.insert(tk.END, f"Logging error: {str(e)}\n")
                
        self.log_thread = threading.Thread(target=log_monitor, daemon=True)
        self.log_thread.start()
        self.update_status("Logging started")
        
    def stop_logging(self):
        try:
            subprocess.run(['adb', 'logcat', '-c'], capture_output=True, timeout=5)
            self.update_status("Logging stopped")
        except:
            pass
            
    def clear_logs(self):
        self.log_text.delete(1.0, tk.END)
        
    def save_logs(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".log",
            filetypes=[("Log files", "*.log"), ("Text files", "*.txt"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                content = self.log_text.get(1.0, tk.END)
                with open(filename, 'w') as f:
                    f.write(content)
                messagebox.showinfo("Success", f"Logs saved to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save logs: {str(e)}")
                
    def export_device_info(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                data = self.tree_to_dict(self.device_info_tree)
                with open(filename, 'w') as f:
                    json.dump({
                        'device_id': self.current_device,
                        'export_time': datetime.now().isoformat(),
                        'device_info': data
                    }, f, indent=2)
                messagebox.showinfo("Success", f"Device info exported to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Export failed: {str(e)}")
                
    def export_scan_results(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                content = self.scan_results.get(1.0, tk.END)
                with open(filename, 'w') as f:
                    f.write(f"NFCman System Scan Results\n")
                    f.write(f"Device: {self.current_device}\n")
                    f.write(f"Export Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write("=" * 50 + "\n\n")
                    f.write(content)
                messagebox.showinfo("Success", f"Scan results exported to {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Export failed: {str(e)}")
                
    def import_firmware(self):
        filename = filedialog.askopenfilename(
            filetypes=[("Binary files", "*.bin"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                with open(filename, 'rb') as f:
                    firmware_data = f.read()
                    
                checksum = hashlib.md5(firmware_data).hexdigest()
                size = len(firmware_data)
                
                result = messagebox.askyesno("Firmware Import",
                                           f"Firmware file: {filename}\n"
                                           f"Size: {size} bytes\n"
                                           f"MD5: {checksum}\n\n"
                                           f"Continue with import?")
                
                if result:
                    self.firmware_text.insert(tk.END, f"\nImported firmware: {filename}\n")
                    self.firmware_text.insert(tk.END, f"Size: {size} bytes\n")
                    self.firmware_text.insert(tk.END, f"Checksum: {checksum}\n")
                    self.firmware_text.insert(tk.END, "Ready for flashing.\n")
                    
            except Exception as e:
                messagebox.showerror("Error", f"Import failed: {str(e)}")
                
    def load_device_profile(self):
        filename = filedialog.askopenfilename(
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                with open(filename, 'r') as f:
                    profile = json.load(f)
                    
                messagebox.showinfo("Success", f"Device profile loaded: {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to load profile: {str(e)}")
                
    def save_device_profile(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        filename = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")]
        )
        
        if filename:
            try:
                profile = {
                    'device_id': self.current_device,
                    'chipset': self.chipset_label.cget('text'),
                    'firmware_version': self.firmware_label.cget('text'),
                    'save_time': datetime.now().isoformat(),
                    'device_info': self.tree_to_dict(self.device_info_tree)
                }
                
                with open(filename, 'w') as f:
                    json.dump(profile, f, indent=2)
                    
                messagebox.showinfo("Success", f"Device profile saved: {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save profile: {str(e)}")
                
    def open_adb_shell(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        if platform.system() == "Windows":
            subprocess.Popen(['cmd', '/c', f'adb -s {self.current_device} shell'])
        else:
            subprocess.Popen(['gnome-terminal', '--', 'adb', '-s', self.current_device, 'shell'])
            
    def enter_fastboot(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        result = messagebox.askyesno("Confirm", "Reboot device into fastboot mode?")
        if result:
            try:
                subprocess.run(['adb', '-s', self.current_device, 'reboot', 'bootloader'], timeout=10)
                messagebox.showinfo("Info", "Device rebooting to fastboot mode")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to enter fastboot: {str(e)}")
                
    def enter_recovery(self):
        if not self.current_device:
            messagebox.showwarning("Warning", "No device connected")
            return
            
        result = messagebox.askyesno("Confirm", "Reboot device into recovery mode?")
        if result:
            try:
                subprocess.run(['adb', '-s', self.current_device, 'reboot', 'recovery'], timeout=10)
                messagebox.showinfo("Info", "Device rebooting to recovery mode")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to enter recovery: {str(e)}")
                
    def open_firmware_analyzer(self):
        analyzer_window = tk.Toplevel(self.root)
        analyzer_window.title("Firmware Analyzer")
        analyzer_window.geometry("800x600")
        analyzer_window.configure(bg='#1a1a1a')
        
        ttk.Label(analyzer_window, text="Firmware Analysis Tools", style='Dark.TLabel', 
                 font=('Arial', 14, 'bold')).pack(pady=10)
        
        analysis_text = scrolledtext.ScrolledText(analyzer_window, bg='#2a2a2a', fg='#ffffff', 
                                                 insertbackground='#ffffff', selectbackground='#3a3a3a')
        analysis_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        analysis_text.insert(tk.END, "Firmware Analyzer - Advanced Analysis Tools\n")
        analysis_text.insert(tk.END, "=" * 50 + "\n\n")
        analysis_text.insert(tk.END, "Available analysis modules:\n")
        analysis_text.insert(tk.END, "- Binary disassembly and decompilation\n")
        analysis_text.insert(tk.END, "- Cryptographic signature verification\n")
        analysis_text.insert(tk.END, "- Memory layout analysis\n")
        analysis_text.insert(tk.END, "- Security vulnerability assessment\n")
        analysis_text.insert(tk.END, "- Hardware abstraction layer mapping\n")
        
    def open_security_profiler(self):
        profiler_window = tk.Toplevel(self.root)
        profiler_window.title("Security Profiler")
        profiler_window.geometry("800x600")
        profiler_window.configure(bg='#1a1a1a')
        
        ttk.Label(profiler_window, text="Security Analysis Profiler", style='Dark.TLabel', 
                 font=('Arial', 14, 'bold')).pack(pady=10)
        
        profiler_text = scrolledtext.ScrolledText(profiler_window, bg='#2a2a2a', fg='#ffffff', 
                                                 insertbackground='#ffffff', selectbackground='#3a3a3a')
        profiler_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        profiler_text.insert(tk.END, "Security Profiler - Comprehensive Security Analysis\n")
        profiler_text.insert(tk.END, "=" * 50 + "\n\n")
        profiler_text.insert(tk.END, "Security analysis capabilities:\n")
        profiler_text.insert(tk.END, "- Attack surface mapping\n")
        profiler_text.insert(tk.END, "- Privilege escalation vectors\n")
        profiler_text.insert(tk.END, "- Exploit mitigation assessment\n")
        profiler_text.insert(tk.END, "- Security mechanism bypass identification\n")
        profiler_text.insert(tk.END, "- Vulnerability correlation analysis\n")
        
    def show_documentation(self):
        doc_window = tk.Toplevel(self.root)
        doc_window.title("Documentation")
        doc_window.geometry("600x500")
        doc_window.configure(bg='#1a1a1a')
        
        ttk.Label(doc_window, text="NFCman Controller Documentation", 
                 style='Dark.TLabel', font=('Arial', 12, 'bold')).pack(pady=10)
        
        doc_text = scrolledtext.ScrolledText(doc_window, bg='#2a2a2a', fg='#ffffff', 
                                           insertbackground='#ffffff', selectbackground='#3a3a3a')
        doc_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        documentation = """
NFCman Controller
========================================

OVERVIEW
--------
The NFCman Controller is a comprehensive tool for Android device 
analysis, security assessment, and NFC chipset management.

FEATURES
--------
- System Monitor: Real-time device monitoring
- Security Manager: Security bypass and modification capabilities
- Reverse Engineering: Simple Automated analysis of system components and binaries
- Firmware Manager: NFC chipset detection, backup, and custom firmware flashing
- APK Manager: Direct APK installation and package management
- Full System Scan: Device analysis and vulnerability assessment

SYSTEM REQUIREMENTS
------------------
- Windows 10/11 or Linux (Ubuntu 18.04+)
- Python 3.7 or later
- Android SDK Platform Tools (ADB)
- USB Debugging enabled on target device
- Root access recommended for advanced features

USAGE INSTRUCTIONS
-----------------
1. Connect Android device via USB
2. Enable USB Debugging in Developer Options
3. Select device from dropdown menu
4. Use Connect button to establish connection
5. Access functionality through tabbed interface

SECURITY WARNINGS
----------------
- This tool can modify critical system components
- Firmware flashing may permanently damage devices
- Security bypasses may void warranties
- Use only on devices you own or have permission to modify
- Always backup firmware before making changes

REVERSE ENGINEERING
------------------
The automated reverse engineering module performs:
- Binary analysis of system components
- Memory mapping and allocation tracking
- System call tracing and analysis
- NFC stack implementation scanning
- Security mechanism identification
- Firmware extraction and analysis
- Vulnerability assessment and reporting

FIRMWARE MANAGEMENT
------------------
Supported NFC chipsets:
- NXP PN544, PN547, PN548 series
- Broadcom BCM20791, BCM20795 series  
- Qualcomm QCA6595 series
- Generic detection for unknown chipsets

Firmware operations:
- Automatic chipset detection
- Firmware version identification
- Complete firmware backup
- Custom firmware flashing
- Safety verification and rollback

LEGAL DISCLAIMER
---------------
This software is for Android security researchers and Developers purposes only.
Users are responsible for compliance with all applicable laws.
Unauthorized access to devices is prohibited.
Use at your own risk - no warranty provided, no author liability

SUPPORT
-------
For support:
- GitHub: https://github.com/CPScript/nfcman
- Issues: https://github.com/CPScript/nfcman/issues
"""
        
        doc_text.insert(tk.END, documentation)
        
    def show_about(self):
        about_window = tk.Toplevel(self.root)
        about_window.title("About")
        about_window.geometry("400x300")
        about_window.configure(bg='#1a1a1a')
        about_window.resizable(False, False)
        
        main_frame = ttk.Frame(about_window, style='Dark.TFrame')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        ttk.Label(main_frame, text="NFCman Controller", 
                 style='Dark.TLabel', font=('Arial', 16, 'bold')).pack(pady=10)
        
        ttk.Label(main_frame, text="Version 3.0", 
                 style='Dark.TLabel', font=('Arial', 12)).pack()
        
        ttk.Label(main_frame, text="Android Analysis Software for NFCman", 
                 style='Dark.TLabel', font=('Arial', 10)).pack(pady=5)
        
        info_text = """
Open source;

Reverse engineering and security analysis tool
for Android devices and NFC chipset management.

Features system monitoring, automated
vulnerability assessment, and custom firmware deployment.

Designed for security researchers, penetration testers,
and embedded systems developers.
        """
        
        ttk.Label(main_frame, text=info_text, style='Dark.TLabel', 
                 font=('Arial', 9), justify=tk.CENTER).pack(pady=20)
        
        ttk.Label(main_frame, text="Copyright 2025 NFCman Project", 
                 style='Dark.TLabel', font=('Arial', 8)).pack()
        
        ttk.Button(main_frame, text="Close", style='Dark.TButton', 
                  command=about_window.destroy).pack(pady=10)
        
    def update_status(self, message):
        self.status_label.config(text=message)
        self.root.update_idletasks()
        
    def log_message(self, message):
        timestamp = datetime.now().strftime('%H:%M:%S')
        log_entry = f"[{timestamp}] {message}\n"
        
        if hasattr(self, 'log_text'):
            self.log_text.insert(tk.END, log_entry)
            self.log_text.see(tk.END)
            
        print(log_entry.strip())
        
    def run(self):
        try:
            self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
            self.root.mainloop()
        except KeyboardInterrupt:
            self.on_closing()
            
    def on_closing(self):
        if self.scanning or self.reverse_engineering_active or self.system_monitor_active:
            result = messagebox.askyesno("Confirm Exit", 
                                       "Operations are still running. Force exit?")
            if not result:
                return
                
        try:
            if hasattr(self, 'log_thread') and self.log_thread.is_alive():
                subprocess.run(['pkill', '-f', 'adb.*logcat'], capture_output=True)
        except:
            pass
            
        self.root.quit()
        self.root.destroy()


class SystemTreeVisualizer:
    def __init__(self, parent_tree):
        self.tree = parent_tree
        self.size_cache = {}
        
    def calculate_directory_sizes(self, device_id):
        directories = [
            '/system', '/vendor', '/data', '/cache', 
            '/sdcard', '/storage', '/proc', '/sys'
        ]
        
        for directory in directories:
            try:
                result = subprocess.run(['adb', '-s', device_id, 'shell', 'du', '-sh', directory], 
                                      capture_output=True, text=True, timeout=30)
                if result.returncode == 0:
                    size_line = result.stdout.strip().split('\n')[-1]
                    size = size_line.split('\t')[0]
                    self.size_cache[directory] = size
            except:
                self.size_cache[directory] = "Unknown"
                
    def create_spacemonger_view(self, device_id):
        self.tree.delete(*self.tree.get_children())
        self.calculate_directory_sizes(device_id)
        
        root_item = self.tree.insert('', 'end', text='Device Storage', 
                                   values=('', 'Root', 'Active'))
        
        for directory, size in self.size_cache.items():
            dir_item = self.tree.insert(root_item, 'end', text=directory, 
                                      values=(size, 'Directory', 'Mounted'))
            
            try:
                result = subprocess.run(['adb', '-s', device_id, 'shell', 'ls', '-la', directory], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')[1:11]
                    for line in lines:
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 9:
                                permissions = parts[0]
                                size_str = parts[4] if len(parts) > 4 else '0'
                                name = ' '.join(parts[8:])
                                
                                item_type = 'Directory' if permissions.startswith('d') else 'File'
                                self.tree.insert(dir_item, 'end', text=name, 
                                               values=(size_str, item_type, 'Normal'))
            except:
                continue
                
        self.tree.item(root_item, open=True)


class FirmwareAnalyzer:
    def __init__(self):
        self.supported_chipsets = {
            '0x544C': {'name': 'NXP PN544', 'family': 'NXP_PN5XX'},
            '0x547C': {'name': 'NXP PN547', 'family': 'NXP_PN5XX'},
            '0x548C': {'name': 'NXP PN548', 'family': 'NXP_PN5XX'},
            '0x2079': {'name': 'Broadcom BCM20791', 'family': 'BROADCOM_BCM'},
            '0x2080': {'name': 'Broadcom BCM20795', 'family': 'BROADCOM_BCM'},
            '0x6595': {'name': 'Qualcomm QCA6595', 'family': 'QUALCOMM_QCA'}
        }
        
    def analyze_firmware_binary(self, firmware_path):
        try:
            with open(firmware_path, 'rb') as f:
                firmware_data = f.read()
                
            analysis = {
                'size': len(firmware_data),
                'md5': hashlib.md5(firmware_data).hexdigest(),
                'sha256': hashlib.sha256(firmware_data).hexdigest(),
                'magic_signatures': self.find_magic_signatures(firmware_data),
                'encryption_detected': self.detect_encryption(firmware_data),
                'entry_points': self.find_entry_points(firmware_data),
                'string_analysis': self.analyze_strings(firmware_data),
                'structure_analysis': self.analyze_structure(firmware_data)
            }
            
            return analysis
        except Exception as e:
            return {'error': str(e)}
            
    def find_magic_signatures(self, data):
        signatures = {
            b'\x7fELF': 'ELF Binary',
            b'MZ': 'PE/DOS Binary',
            b'\x89PNG': 'PNG Image',
            b'JFIF': 'JPEG Image',
            b'\x50\x4B': 'ZIP Archive',
            b'\x1F\x8B': 'GZIP Archive',
            b'BZh': 'BZIP2 Archive'
        }
        
        found_signatures = []
        for signature, description in signatures.items():
            if signature in data[:1024]:
                offset = data.find(signature)
                found_signatures.append({'signature': description, 'offset': offset})
                
        return found_signatures
        
    def detect_encryption(self, data):
        entropy = self.calculate_entropy(data)
        return entropy > 7.5
        
    def calculate_entropy(self, data):
        if not data:
            return 0
            
        counts = [0] * 256
        for byte in data:
            counts[byte] += 1
            
        entropy = 0
        length = len(data)
        for count in counts:
            if count > 0:
                probability = count / length
                entropy -= probability * (probability.bit_length() - 1)
                
        return entropy
        
    def find_entry_points(self, data):
        entry_points = []
        
        arm_signatures = [
            b'\x00\x00\x00\xEA',  # ARM branch instruction
            b'\xFE\xFF\xFF\xEA',  # ARM infinite loop
            b'\x00\x00\x00\xE1'   # ARM NOP
        ]
        
        for i, signature in enumerate(arm_signatures):
            offset = data.find(signature)
            if offset != -1:
                entry_points.append({'type': f'ARM_{i}', 'offset': offset})
                
        return entry_points
        
    def analyze_strings(self, data):
        strings = []
        current_string = ""
        
        for byte in data:
            if 32 <= byte <= 126:
                current_string += chr(byte)
            else:
                if len(current_string) >= 4:
                    strings.append(current_string)
                current_string = ""
                
        if len(current_string) >= 4:
            strings.append(current_string)
            
        interesting_strings = []
        keywords = ['nfc', 'chip', 'firmware', 'version', 'init', 'config', 'security']
        
        for string in strings:
            if any(keyword in string.lower() for keyword in keywords):
                interesting_strings.append(string)
                
        return interesting_strings[:20]
        
    def analyze_structure(self, data):
        structure = {
            'sections': [],
            'probable_code_sections': [],
            'probable_data_sections': []
        }
        
        chunk_size = 4096
        for i in range(0, len(data), chunk_size):
            chunk = data[i:i+chunk_size]
            entropy = self.calculate_entropy(chunk)
            
            if entropy > 7.0:
                structure['probable_code_sections'].append({
                    'offset': i,
                    'size': len(chunk),
                    'entropy': entropy
                })
            elif entropy < 3.0:
                structure['probable_data_sections'].append({
                    'offset': i,
                    'size': len(chunk),
                    'entropy': entropy
                })
                
        return structure


class SecurityBypassEngine:
    def __init__(self, device_id):
        self.device_id = device_id
        self.bypass_methods = []
        
    def analyze_security_landscape(self):
        security_info = {
            'selinux_status': self.check_selinux(),
            'root_access': self.check_root_access(),
            'encryption_status': self.check_encryption(),
            'verified_boot': self.check_verified_boot(),
            'dm_verity': self.check_dm_verity(),
            'bootloader_status': self.check_bootloader_status()
        }
        
        self.identify_bypass_methods(security_info)
        return security_info
        
    def check_selinux(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'getenforce'], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Error"
            
    def check_root_access(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'su', '-c', 'id'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except:
            return False
            
    def check_encryption(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'getprop', 'ro.crypto.state'], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Error"
            
    def check_verified_boot(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'getprop', 'ro.boot.verifiedbootstate'], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Error"
            
    def check_dm_verity(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'getprop', 'ro.boot.veritymode'], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Error"
            
    def check_bootloader_status(self):
        try:
            result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'getprop', 'ro.boot.flash.locked'], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip() if result.returncode == 0 else "Unknown"
        except:
            return "Error"
            
    def identify_bypass_methods(self, security_info):
        self.bypass_methods = []
        
        if security_info['selinux_status'] == 'Enforcing':
            self.bypass_methods.append({
                'target': 'SELinux',
                'method': 'Policy modification',
                'risk': 'Medium',
                'commands': ['setenforce 0', 'echo 0 > /sys/fs/selinux/enforce']
            })
            
        if not security_info['root_access']:
            self.bypass_methods.append({
                'target': 'Root Access',
                'method': 'Privilege escalation',
                'risk': 'High',
                'commands': ['su', 'exploits/local_privilege_escalation']
            })
            
        if security_info['dm_verity'] == 'enforcing':
            self.bypass_methods.append({
                'target': 'DM-Verity',
                'method': 'Verification bypass',
                'risk': 'High',
                'commands': ['echo 0 > /sys/module/dm_verity/parameters/enabled']
            })
            
    def execute_bypass_sequence(self, target_bypass):
        results = []
        
        for command in target_bypass['commands']:
            try:
                result = subprocess.run(['adb', '-s', self.device_id, 'shell', 'su', '-c', command], 
                                      capture_output=True, text=True, timeout=10)
                results.append({
                    'command': command,
                    'return_code': result.returncode,
                    'stdout': result.stdout,
                    'stderr': result.stderr
                })
            except Exception as e:
                results.append({
                    'command': command,
                    'error': str(e)
                })
                
        return results


def main():
    try:
        app = NFCControllerGUI()
        app.run()
    except Exception as e:
        print(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
