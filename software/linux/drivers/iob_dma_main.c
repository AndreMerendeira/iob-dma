/* iob_dma_main.c: driver for iob_dma
 * using device platform. No hardcoded hardware address:
 * 1. load driver: insmod iob_dma.ko
 * 2. run user app: ./user/user
 */

#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>

#include "iob_class/iob_class_utils.h"
#include "iob_dma.h"

static int iob_dma_probe(struct platform_device *);
static int iob_dma_remove(struct platform_device *);

static int iob_dma_mmap(struct file *file, struct vm_area_struct *vma);
static ssize_t iob_dma_read(struct file *, char __user *, size_t, loff_t *);
static ssize_t iob_dma_write(struct file *, const char __user *, size_t,
                               loff_t *);
static loff_t iob_dma_llseek(struct file *, loff_t, int);
static int iob_dma_open(struct inode *, struct file *);
static int iob_dma_release(struct inode *, struct file *);

static void iob_dma_vm_close(struct vm_area_struct *vma);

static struct iob_data iob_dma_data = {0};
DEFINE_MUTEX(iob_dma_mutex);

#include "iob_dma_sysfs.h"

static const struct file_operations iob_dma_fops = {
    .owner = THIS_MODULE,
    .write = iob_dma_write,
    .read = iob_dma_read,
    .llseek = iob_dma_llseek,
    .open = iob_dma_open,
    .release = iob_dma_release,
    .mmap = iob_dma_mmap,
};

static struct vm_operations_struct iob_dma_vm_ops = {
    .close = iob_dma_vm_close,
};

static const struct of_device_id of_iob_dma_match[] = {
    {.compatible = "iobundle,dma0"},
    {},
};

static struct platform_driver iob_dma_driver = {
    .driver =
        {
            .name = "iob_dma",
            .owner = THIS_MODULE,
            .of_match_table = of_iob_dma_match,
        },
    .probe = iob_dma_probe,
    .remove = iob_dma_remove,
};

//
// Module init and exit functions
//
static int iob_dma_probe(struct platform_device *pdev) {
  struct resource *res;
  int result = 0;

  if (iob_dma_data.device != NULL) {
    pr_err("[Driver] %s: No more devices allowed!\n", IOB_DMA_DRIVER_NAME);

    return -ENODEV;
  }

  pr_info("[Driver] %s: probing.\n", IOB_DMA_DRIVER_NAME);

  // Get the I/O region base address
  res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
  if (!res) {
    pr_err("[Driver]: Failed to get I/O resource!\n");
    result = -ENODEV;
    goto r_get_resource;
  }

  // Request and map the I/O region
  iob_dma_data.regbase = devm_ioremap_resource(&pdev->dev, res);
  if (IS_ERR(iob_dma_data.regbase)) {
    result = PTR_ERR(iob_dma_data.regbase);
    goto r_ioremmap;
  }
  iob_dma_data.regsize = resource_size(res);

  // Alocate char device
  result =
      alloc_chrdev_region(&iob_dma_data.devnum, 0, 1, IOB_DMA_DRIVER_NAME);
  if (result) {
    pr_err("%s: Failed to allocate device number!\n", IOB_DMA_DRIVER_NAME);
    goto r_alloc_region;
  }

  cdev_init(&iob_dma_data.cdev, &iob_dma_fops);

  result = cdev_add(&iob_dma_data.cdev, iob_dma_data.devnum, 1);
  if (result) {
    pr_err("%s: Char device registration failed!\n", IOB_DMA_DRIVER_NAME);
    goto r_cdev_add;
  }

  // Create device class // todo: make a dummy driver just to create and own the
  // class: https://stackoverflow.com/a/16365027/8228163
  if ((iob_dma_data.class =
           class_create(THIS_MODULE, IOB_DMA_DRIVER_CLASS)) == NULL) {
    printk("Device class can not be created!\n");
    goto r_class;
  }

  // Create device file
  iob_dma_data.device =
      device_create(iob_dma_data.class, NULL, iob_dma_data.devnum, NULL,
                    IOB_DMA_DRIVER_NAME);
  if (iob_dma_data.device == NULL) {
    printk("Can not create device file!\n");
    goto r_device;
  }

  result = iob_dma_create_device_attr_files(iob_dma_data.device);
  if (result) {
    pr_err("Cannot create device attribute file......\n");
    goto r_dev_file;
  }

  dev_info(&pdev->dev, "initialized.\n");
  goto r_ok;

r_dev_file:
  iob_dma_remove_device_attr_files(&iob_dma_data);
r_device:
  class_destroy(iob_dma_data.class);
r_class:
  cdev_del(&iob_dma_data.cdev);
r_cdev_add:
  unregister_chrdev_region(iob_dma_data.devnum, 1);
r_alloc_region:
  // iounmap is managed by devm
r_ioremmap:
r_get_resource:
r_ok:

  return result;
}

static int iob_dma_remove(struct platform_device *pdev) {
  iob_dma_remove_device_attr_files(&iob_dma_data);
  class_destroy(iob_dma_data.class);
  cdev_del(&iob_dma_data.cdev);
  unregister_chrdev_region(iob_dma_data.devnum, 1);
  // Note: no need for iounmap, since we are using devm_ioremap_resource()

  dev_info(&pdev->dev, "exiting.\n");

  return 0;
}

static int __init iob_dma_init(void) {
  pr_info("[Driver] %s: initializing.\n", IOB_DMA_DRIVER_NAME);

  return platform_driver_register(&iob_dma_driver);
}

static void __exit iob_dma_exit(void) {
  pr_info("[Driver] %s: exiting.\n", IOB_DMA_DRIVER_NAME);
  platform_driver_unregister(&iob_dma_driver);
}

static void iob_dma_vm_close(struct vm_area_struct *vma) {
    int page_mask = 0;
    void *virtual_addr = NULL;
    int clog2_num_pages = 0;
    uintptr_t priv_data = (uintptr_t) vma->vm_private_data;

    page_mask = (1 << PAGE_SHIFT)-1;
    virtual_addr = (void *) (priv_data & ~page_mask);
    clog2_num_pages = (int) (priv_data & page_mask);

    pr_info("[Driver] VM: Closing virtual address: %p\n", virtual_addr);

    free_pages((unsigned long) virtual_addr, clog2_num_pages);
}

//
// File operations
//

static int iob_dma_open(struct inode *inode, struct file *file) {
  pr_info("[Driver] iob_dma device opened\n");

  if (!mutex_trylock(&iob_dma_mutex)) {
    pr_info("Another process is accessing the device\n");

    return -EBUSY;
  }

  return 0;
}

static int iob_dma_release(struct inode *inode, struct file *file) {
  pr_info("[Driver] iob_dma device closed\n");

  mutex_unlock(&iob_dma_mutex);

  return 0;
}

static unsigned int ceil_log2(int val){
   unsigned int clog2 = 0;
   while((1 << clog2) < val){
      clog2 += 1;
   }
   return clog2;
}

static int iob_dma_mmap(struct file *file, struct vm_area_struct *vma) {
    unsigned long size = 0;
    int page_size = 0;
    unsigned long page_start = 0;
    int num_pages = 0;
    int clog2_num_pages = 0;
    struct page *page = NULL;
    void *physical_addr = NULL;
    void *virtual_addr = NULL;
    int res = 0;

    size = (unsigned long) vma->vm_end - vma->vm_start;
    page_size = 1 << PAGE_SHIFT;
    pr_info("[Driver] MMAP: Page Size: %d\tsize = %lu\n", page_size, size);

    // Only support page aligned sizes - size must be multiple of page_size
    if (size % page_size != 0) {
        pr_err("[Driver] MMAP: Size not page aligned\n");
        return -EINVAL;
    }

    // same as ceil(size/page_size), since size = k*page_size
    num_pages = size / page_size;
    clog2_num_pages = ceil_log2(num_pages);

    page = alloc_pages(GFP_KERNEL, clog2_num_pages);
    if (page == NULL) {
        pr_err("[Driver] MMAP: Failed to allocate pages\n");
        return -ENOMEM;
    }

    page_start = page_to_pfn(page);
    res = remap_pfn_range(vma, vma->vm_start, page_start, size, vma->vm_page_prot);
    if (res != 0) {
        pr_err("[Driver] MMAP: Failed to remap pages\n");
        __free_pages(page, clog2_num_pages);
        return -EAGAIN;
    }

    // Set BASE_ADDR to physical address
    virtual_addr = page_address(page);
    physical_addr = (void *) virt_to_phys(virtual_addr);
    iob_data_write_reg(iob_dma_data.regbase, (uint32_t) physical_addr, IOB_DMA_BASE_ADDR_ADDR,
                       IOB_DMA_BASE_ADDR_W);
    pr_info("[Driver] BASE_ADDR iob_dma: %p\n", physical_addr);
    
    // Store order in the lower bits that are guaranteed to be zero
    // because virtual_mem is page aligned
    vma->vm_private_data = (void *) ((uintptr_t) virtual_addr | (uintptr_t) clog2_num_pages);
    vma->vm_ops = &iob_dma_vm_ops;

    return 0;
}

static ssize_t iob_dma_read(struct file *file, char __user *buf, size_t count,
                              loff_t *ppos) {
  int size = 0;
  u32 value = 0;

  /* read value from register */
  switch (*ppos) {
  case IOB_DMA_READY_R_ADDR:
    value = iob_data_read_reg(iob_dma_data.regbase, IOB_DMA_READY_R_ADDR,
                              IOB_DMA_READY_R_W);
    size = (IOB_DMA_READY_R_W >> 3); // bit to bytes
    pr_info("[Driver] Read READY_R!\n");
    break;
  case IOB_DMA_READY_W_ADDR:
    value = iob_data_read_reg(iob_dma_data.regbase, IOB_DMA_READY_W_ADDR,
                              IOB_DMA_READY_W_W);
    size = (IOB_DMA_READY_W_W >> 3); // bit to bytes
    pr_info("[Driver] Read READY_W!\n");
    break;
  case IOB_DMA_VERSION_ADDR:
    value = iob_data_read_reg(iob_dma_data.regbase, IOB_DMA_VERSION_ADDR,
                              IOB_DMA_VERSION_W);
    size = (IOB_DMA_VERSION_W >> 3); // bit to bytes
    pr_info("[Driver] Read version!\n");
    break;
  default:
    // invalid address - no bytes read
    return 0;
  }

  // Read min between count and REG_SIZE
  if (size > count)
    size = count;

  if (copy_to_user(buf, &value, size))
    return -EFAULT;

  return count;
}

static ssize_t iob_dma_write(struct file *file, const char __user *buf,
                               size_t count, loff_t *ppos) {
  int size = 0;
  u32 value = 0;

  switch (*ppos) {
  case IOB_DMA_BASE_ADDR_ADDR:
    size = (IOB_DMA_BASE_ADDR_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_dma_data.regbase, value, IOB_DMA_BASE_ADDR_ADDR,
                       IOB_DMA_BASE_ADDR_W);
    pr_info("[Driver] BASE_ADDR iob_dma: 0x%x\n", value);
    break;
  case IOB_DMA_TRANSFER_SIZE_ADDR:
    size = (IOB_DMA_TRANSFER_SIZE_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_dma_data.regbase, value, IOB_DMA_TRANSFER_SIZE_ADDR,
                       IOB_DMA_TRANSFER_SIZE_W);
    pr_info("[Driver] TRANSFER_SIZE iob_dma: 0x%x\n", value);
    break;
  case IOB_DMA_DIRECTION_ADDR:
    size = (IOB_DMA_DIRECTION_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_dma_data.regbase, value, IOB_DMA_DIRECTION_ADDR,
                       IOB_DMA_DIRECTION_W);
    pr_info("[Driver] DIRECTION iob_dma: 0x%x\n", value);
    break;
  case IOB_DMA_INTERFACE_NUM_ADDR:
    size = (IOB_DMA_INTERFACE_NUM_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_dma_data.regbase, value, IOB_DMA_INTERFACE_NUM_ADDR,
                       IOB_DMA_INTERFACE_NUM_W);
    pr_info("[Driver] INTERFACE_NUM iob_dma: 0x%x\n", value);
    break;
  default:
    pr_info("[Driver] Invalid write address 0x%x\n", (unsigned int)*ppos);
    // invalid address - no bytes written
    return 0;
  }

  return count;
}

/* Custom lseek function
 * check: lseek(2) man page for whence modes
 */
static loff_t iob_dma_llseek(struct file *filp, loff_t offset, int whence) {
  loff_t new_pos = -1;

  switch (whence) {
  case SEEK_SET:
    new_pos = offset;
    break;
  case SEEK_CUR:
    new_pos = filp->f_pos + offset;
    break;
  case SEEK_END:
    new_pos = (1 << IOB_DMA_SWREG_ADDR_W) + offset;
    break;
  default:
    return -EINVAL;
  }

  // Check for valid bounds
  if (new_pos < 0 || new_pos > iob_dma_data.regsize) {
    return -EINVAL;
  }

  // Update file position
  filp->f_pos = new_pos;

  return new_pos;
}

module_init(iob_dma_init);
module_exit(iob_dma_exit);

MODULE_LICENSE("Dual MIT/GPL");
MODULE_AUTHOR("IObundle");
MODULE_DESCRIPTION("IOb-DMA Drivers");
MODULE_VERSION("0.10");
