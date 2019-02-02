
obj/bootblock.o:     file format elf32-i386


Disassembly of section .startup:

00007c00 <start>:

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts
    7c00:	fa                   	cli    
    cld                                             # String operations increment
    7c01:	fc                   	cld    

    # Set up the important data segment registers (DS, ES, SS).
    xorw %ax, %ax                                   # Segment number zero
    7c02:	31 c0                	xor    %eax,%eax
    movw %ax, %ds                                   # -> Data Segment
    7c04:	8e d8                	mov    %eax,%ds
    movw %ax, %es                                   # -> Extra Segment
    7c06:	8e c0                	mov    %eax,%es
    movw %ax, %ss                                   # -> Stack Segment
    7c08:	8e d0                	mov    %eax,%ss

00007c0a <seta20.1>:
    # Enable A20:
    #  For backwards compatibility with the earliest PCs, physical
    #  address line 20 is tied low, so that addresses higher than
    #  1MB wrap around to zero by default. This code undoes this.
seta20.1:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    7c0a:	e4 64                	in     $0x64,%al
    testb $0x2, %al
    7c0c:	a8 02                	test   $0x2,%al
    jnz seta20.1
    7c0e:	75 fa                	jne    7c0a <seta20.1>

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    7c10:	b0 d1                	mov    $0xd1,%al
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port
    7c12:	e6 64                	out    %al,$0x64

00007c14 <seta20.2>:

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    7c14:	e4 64                	in     $0x64,%al
    testb $0x2, %al
    7c16:	a8 02                	test   $0x2,%al
    jnz seta20.2
    7c18:	75 fa                	jne    7c14 <seta20.2>

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    7c1a:	b0 df                	mov    $0xdf,%al
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1
    7c1c:	e6 60                	out    %al,$0x60

00007c1e <probe_memory>:

probe_memory:
    movl $0, 0x8000
    7c1e:	66 c7 06 00 80       	movw   $0x8000,(%esi)
    7c23:	00 00                	add    %al,(%eax)
    7c25:	00 00                	add    %al,(%eax)
    xorl %ebx, %ebx
    7c27:	66 31 db             	xor    %bx,%bx
    movw $0x8004, %di
    7c2a:	bf                   	.byte 0xbf
    7c2b:	04 80                	add    $0x80,%al

00007c2d <start_probe>:
start_probe:
    movl $0xE820, %eax
    7c2d:	66 b8 20 e8          	mov    $0xe820,%ax
    7c31:	00 00                	add    %al,(%eax)
    movl $20, %ecx
    7c33:	66 b9 14 00          	mov    $0x14,%cx
    7c37:	00 00                	add    %al,(%eax)
    movl $SMAP, %edx
    7c39:	66 ba 50 41          	mov    $0x4150,%dx
    7c3d:	4d                   	dec    %ebp
    7c3e:	53                   	push   %ebx
    int $0x15
    7c3f:	cd 15                	int    $0x15
    jnc cont
    7c41:	73 08                	jae    7c4b <cont>
    movw $12345, 0x8000
    7c43:	c7 06 00 80 39 30    	movl   $0x30398000,(%esi)
    jmp finish_probe
    7c49:	eb 0e                	jmp    7c59 <finish_probe>

00007c4b <cont>:
cont:
    addw $20, %di
    7c4b:	83 c7 14             	add    $0x14,%edi
    incl 0x8000
    7c4e:	66 ff 06             	incw   (%esi)
    7c51:	00 80 66 83 fb 00    	add    %al,0xfb8366(%eax)
    cmpl $0, %ebx
    jnz start_probe
    7c57:	75 d4                	jne    7c2d <start_probe>

00007c59 <finish_probe>:

    # Switch from real to protected mode, using a bootstrap GDT
    # and segment translation that makes virtual addresses
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
    lgdt gdtdesc
    7c59:	0f 01 16             	lgdtl  (%esi)
    7c5c:	c4 7d 0f             	les    0xf(%ebp),%edi
    movl %cr0, %eax
    7c5f:	20 c0                	and    %al,%al
    orl $CR0_PE_ON, %eax
    7c61:	66 83 c8 01          	or     $0x1,%ax
    movl %eax, %cr0
    7c65:	0f 22 c0             	mov    %eax,%cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.
    ljmp $PROT_MODE_CSEG, $protcseg
    7c68:	ea                   	.byte 0xea
    7c69:	6d                   	insl   (%dx),%es:(%edi)
    7c6a:	7c 08                	jl     7c74 <protcseg+0x7>
	...

00007c6d <protcseg>:

.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    7c6d:	66 b8 10 00          	mov    $0x10,%ax
    movw %ax, %ds                                   # -> DS: Data Segment
    7c71:	8e d8                	mov    %eax,%ds
    movw %ax, %es                                   # -> ES: Extra Segment
    7c73:	8e c0                	mov    %eax,%es
    movw %ax, %fs                                   # -> FS
    7c75:	8e e0                	mov    %eax,%fs
    movw %ax, %gs                                   # -> GS
    7c77:	8e e8                	mov    %eax,%gs
    movw %ax, %ss                                   # -> SS: Stack Segment
    7c79:	8e d0                	mov    %eax,%ss

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    7c7b:	bd 00 00 00 00       	mov    $0x0,%ebp
    movl $start, %esp
    7c80:	bc 00 7c 00 00       	mov    $0x7c00,%esp
    call bootmain
    7c85:	e8 74 00 00 00       	call   7cfe <bootmain>

00007c8a <spin>:

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin
    7c8a:	eb fe                	jmp    7c8a <spin>

Disassembly of section .text:

00007c8c <readsect>:
        /* do nothing */;
}

/* readsect - read a single sector at @secno into @dst */
static void
readsect(void *dst, uint32_t secno) {
    7c8c:	55                   	push   %ebp
    7c8d:	89 e5                	mov    %esp,%ebp
    7c8f:	57                   	push   %edi
    7c90:	53                   	push   %ebx
    7c91:	89 c7                	mov    %eax,%edi
    7c93:	89 d1                	mov    %edx,%ecx
static inline void invlpg(void *addr) __attribute__((always_inline));

static inline uint8_t
inb(uint16_t port) {
    uint8_t data;
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
    7c95:	bb f7 01 00 00       	mov    $0x1f7,%ebx
    7c9a:	89 da                	mov    %ebx,%edx
    7c9c:	ec                   	in     (%dx),%al
    while ((inb(0x1F7) & 0xC0) != 0x40)
    7c9d:	83 e0 c0             	and    $0xffffffc0,%eax
    7ca0:	3c 40                	cmp    $0x40,%al
    7ca2:	75 f6                	jne    7c9a <readsect+0xe>
        : "memory", "cc");
}

static inline void
outb(uint16_t port, uint8_t data) {
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
    7ca4:	b0 01                	mov    $0x1,%al
    7ca6:	ba f2 01 00 00       	mov    $0x1f2,%edx
    7cab:	ee                   	out    %al,(%dx)
    7cac:	ba f3 01 00 00       	mov    $0x1f3,%edx
    7cb1:	88 c8                	mov    %cl,%al
    7cb3:	ee                   	out    %al,(%dx)
    // wait for disk to be ready
    waitdisk();

    outb(0x1F2, 1);                         // count = 1
    outb(0x1F3, secno & 0xFF);
    outb(0x1F4, (secno >> 8) & 0xFF);
    7cb4:	89 c8                	mov    %ecx,%eax
    7cb6:	c1 e8 08             	shr    $0x8,%eax
    7cb9:	ba f4 01 00 00       	mov    $0x1f4,%edx
    7cbe:	ee                   	out    %al,(%dx)
    outb(0x1F5, (secno >> 16) & 0xFF);
    7cbf:	89 c8                	mov    %ecx,%eax
    7cc1:	c1 e8 10             	shr    $0x10,%eax
    7cc4:	ba f5 01 00 00       	mov    $0x1f5,%edx
    7cc9:	ee                   	out    %al,(%dx)
    outb(0x1F6, ((secno >> 24) & 0xF) | 0xE0);
    7cca:	89 c8                	mov    %ecx,%eax
    7ccc:	c1 e8 18             	shr    $0x18,%eax
    7ccf:	83 e0 0f             	and    $0xf,%eax
    7cd2:	83 c8 e0             	or     $0xffffffe0,%eax
    7cd5:	ba f6 01 00 00       	mov    $0x1f6,%edx
    7cda:	ee                   	out    %al,(%dx)
    7cdb:	b0 20                	mov    $0x20,%al
    7cdd:	89 da                	mov    %ebx,%edx
    7cdf:	ee                   	out    %al,(%dx)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
    7ce0:	ba f7 01 00 00       	mov    $0x1f7,%edx
    7ce5:	ec                   	in     (%dx),%al
    while ((inb(0x1F7) & 0xC0) != 0x40)
    7ce6:	83 e0 c0             	and    $0xffffffc0,%eax
    7ce9:	3c 40                	cmp    $0x40,%al
    7ceb:	75 f8                	jne    7ce5 <readsect+0x59>
    asm volatile (
    7ced:	b9 80 00 00 00       	mov    $0x80,%ecx
    7cf2:	ba f0 01 00 00       	mov    $0x1f0,%edx
    7cf7:	fc                   	cld    
    7cf8:	f2 6d                	repnz insl (%dx),%es:(%edi)
    // wait for disk to be ready
    waitdisk();

    // read a sector
    insl(0x1F0, dst, SECTSIZE / 4);
}
    7cfa:	5b                   	pop    %ebx
    7cfb:	5f                   	pop    %edi
    7cfc:	5d                   	pop    %ebp
    7cfd:	c3                   	ret    

00007cfe <bootmain>:
    }
}

/* bootmain - the entry of bootloader */
void
bootmain(void) {
    7cfe:	55                   	push   %ebp
    7cff:	89 e5                	mov    %esp,%ebp
    7d01:	57                   	push   %edi
    7d02:	56                   	push   %esi
    7d03:	53                   	push   %ebx
    7d04:	83 ec 1c             	sub    $0x1c,%esp
    uint32_t secno = (offset / SECTSIZE) + 1;
    7d07:	bb 01 00 00 00       	mov    $0x1,%ebx
        readsect((void *)va, secno);
    7d0c:	89 d8                	mov    %ebx,%eax
    7d0e:	c1 e0 09             	shl    $0x9,%eax
    7d11:	05 00 fe 00 00       	add    $0xfe00,%eax
    7d16:	89 da                	mov    %ebx,%edx
    7d18:	e8 6f ff ff ff       	call   7c8c <readsect>
    for (; va < end_va; va += SECTSIZE, secno ++) {
    7d1d:	43                   	inc    %ebx
    7d1e:	83 fb 09             	cmp    $0x9,%ebx
    7d21:	75 e9                	jne    7d0c <bootmain+0xe>
    // read the 1st page off disk
    readseg((uintptr_t)ELFHDR, SECTSIZE * 8, 0);

    // is this a valid ELF?
    if (ELFHDR->e_magic != ELF_MAGIC) {
    7d23:	81 3d 00 00 01 00 7f 	cmpl   $0x464c457f,0x10000
    7d2a:	45 4c 46 
    7d2d:	75 6a                	jne    7d99 <bootmain+0x9b>
    }

    struct proghdr *ph, *eph;

    // load each program segment (ignores ph flags)
    ph = (struct proghdr *)((uintptr_t)ELFHDR + ELFHDR->e_phoff);
    7d2f:	a1 1c 00 01 00       	mov    0x1001c,%eax
    7d34:	8d 98 00 00 01 00    	lea    0x10000(%eax),%ebx
    eph = ph + ELFHDR->e_phnum;
    7d3a:	0f b7 05 2c 00 01 00 	movzwl 0x1002c,%eax
    7d41:	c1 e0 05             	shl    $0x5,%eax
    7d44:	01 d8                	add    %ebx,%eax
    7d46:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    for (; ph < eph; ph ++) {
    7d49:	3b 5d e4             	cmp    -0x1c(%ebp),%ebx
    7d4c:	73 3f                	jae    7d8d <bootmain+0x8f>
        readseg(ph->p_va & 0xFFFFFF, ph->p_memsz, ph->p_offset);
    7d4e:	8b 4b 04             	mov    0x4(%ebx),%ecx
    7d51:	8b 73 08             	mov    0x8(%ebx),%esi
    7d54:	81 e6 ff ff ff 00    	and    $0xffffff,%esi
    uintptr_t end_va = va + count;
    7d5a:	8b 43 14             	mov    0x14(%ebx),%eax
    7d5d:	01 f0                	add    %esi,%eax
    7d5f:	89 45 e0             	mov    %eax,-0x20(%ebp)
    va -= offset % SECTSIZE;
    7d62:	89 c8                	mov    %ecx,%eax
    7d64:	25 ff 01 00 00       	and    $0x1ff,%eax
    7d69:	29 c6                	sub    %eax,%esi
    uint32_t secno = (offset / SECTSIZE) + 1;
    7d6b:	c1 e9 09             	shr    $0x9,%ecx
    7d6e:	8d 79 01             	lea    0x1(%ecx),%edi
    for (; va < end_va; va += SECTSIZE, secno ++) {
    7d71:	39 75 e0             	cmp    %esi,-0x20(%ebp)
    7d74:	76 12                	jbe    7d88 <bootmain+0x8a>
        readsect((void *)va, secno);
    7d76:	89 fa                	mov    %edi,%edx
    7d78:	89 f0                	mov    %esi,%eax
    7d7a:	e8 0d ff ff ff       	call   7c8c <readsect>
    for (; va < end_va; va += SECTSIZE, secno ++) {
    7d7f:	81 c6 00 02 00 00    	add    $0x200,%esi
    7d85:	47                   	inc    %edi
    7d86:	eb e9                	jmp    7d71 <bootmain+0x73>
    for (; ph < eph; ph ++) {
    7d88:	83 c3 20             	add    $0x20,%ebx
    7d8b:	eb bc                	jmp    7d49 <bootmain+0x4b>
    }

    // call the entry point from the ELF header
    // note: does not return
    ((void (*)(void))(ELFHDR->e_entry & 0xFFFFFF))();
    7d8d:	a1 18 00 01 00       	mov    0x10018,%eax
    7d92:	25 ff ff ff 00       	and    $0xffffff,%eax
    7d97:	ff d0                	call   *%eax
}

static inline void
outw(uint16_t port, uint16_t data) {
    asm volatile ("outw %0, %1" :: "a" (data), "d" (port) : "memory");
    7d99:	ba 00 8a ff ff       	mov    $0xffff8a00,%edx
    7d9e:	89 d0                	mov    %edx,%eax
    7da0:	66 ef                	out    %ax,(%dx)
    7da2:	b8 00 8e ff ff       	mov    $0xffff8e00,%eax
    7da7:	66 ef                	out    %ax,(%dx)
    7da9:	eb fe                	jmp    7da9 <bootmain+0xab>
