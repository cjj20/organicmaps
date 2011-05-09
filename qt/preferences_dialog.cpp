#include "preferences_dialog.hpp"

#include "../map/languages.hpp"

#include <QtGui/QIcon>
#include <QtGui/QCheckBox>
#include <QtGui/QHBoxLayout>
#include <QtGui/QVBoxLayout>
#include <QtGui/QTableWidget>
#include <QtGui/QHeaderView>
#include <QtGui/QPushButton>

namespace qt
{
  PreferencesDialog::PreferencesDialog(QWidget * parent, bool & autoUpdatesEnabled)
  : QDialog(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint),
    m_autoUpdatesEnabled(autoUpdatesEnabled)
  {
    QIcon icon(":logo.png");
    setWindowIcon(icon);
    setWindowTitle(tr("Preferences"));

    m_pTable = new QTableWidget(0, 2, this);
    m_pTable->setAlternatingRowColors(true);
    m_pTable->setShowGrid(false);
    m_pTable->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_pTable->verticalHeader()->setVisible(false);
    m_pTable->horizontalHeader()->setVisible(false);
    m_pTable->horizontalHeader()->setStretchLastSection(true);

    languages::CodesAndNamesT langList;
    languages::GetCurrentSettings(langList);
    for (size_t i = 0; i < langList.size(); ++i)
    {
      m_pTable->insertRow(i);
      QTableWidgetItem * c1 = new QTableWidgetItem(langList[i].first.c_str());
      c1->setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled);
      m_pTable->setItem(i, 0, c1);
      QTableWidgetItem * c2 = new QTableWidgetItem(QString::fromUtf8(langList[i].second.c_str()));
      c2->setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled);
      m_pTable->setItem(i, 1, c2);
    }

    QPushButton * upButton = new QPushButton();
    upButton->setIcon(QIcon(":/navig64/up.png"));
    upButton->setToolTip(tr("Move up"));
    upButton->setDefault(false);
    connect(upButton, SIGNAL(clicked()), this, SLOT(OnUpClick()));

    QPushButton * downButton = new QPushButton();
    downButton->setIcon(QIcon(":/navig64/down.png"));
    downButton->setToolTip(tr("Move down"));
    downButton->setDefault(false);
    connect(downButton, SIGNAL(clicked()), this, SLOT(OnDownClick()));

    QPushButton * closeButton = new QPushButton(tr("Close"));
    closeButton->setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
    closeButton->setDefault(true);
    connect(closeButton, SIGNAL(clicked()), this, SLOT(OnCloseClick()));

    QVBoxLayout * vBox = new QVBoxLayout();
    vBox->addWidget(upButton);
    vBox->addWidget(downButton);

    QHBoxLayout * hBox = new QHBoxLayout();
    hBox->addLayout(vBox);
    hBox->addWidget(m_pTable);

    QHBoxLayout * bottomLayout = new QHBoxLayout();
    bottomLayout->addStretch(1);
    bottomLayout->setSpacing(0);
    bottomLayout->addWidget(closeButton);

    QVBoxLayout * finalBox = new QVBoxLayout();
    finalBox->addLayout(hBox);
    finalBox->addLayout(bottomLayout);
    setLayout(finalBox);

    if (m_pTable->rowCount() > 0)
      m_pTable->selectRow(0);
  }

  void PreferencesDialog::OnCloseClick()
  {
    done(0);
  }

  static void SwapRows(QTableWidget & widget, int row1, int row2)
  {
    QTableWidgetItem * c0 = widget.takeItem(row1, 0);
    QTableWidgetItem * c1 = widget.takeItem(row1, 1);
    widget.setItem(row1, 0, widget.takeItem(row2, 0));
    widget.setItem(row1, 1, widget.takeItem(row2, 1));
    widget.setItem(row2, 0, c0);
    widget.setItem(row2, 1, c1);
  }

  static void ShiftSelectionRange(QList<QTableWidgetSelectionRange> & range, int offset)
  {
    QList<QTableWidgetSelectionRange> newRange;
    for (int i = 0; i < range.size(); ++i)
      newRange.append(QTableWidgetSelectionRange(range[i].topRow() + offset,
                                                 range[i].leftColumn(),
                                                 range[i].bottomRow() + offset,
                                                 range[i].rightColumn()));
    range = newRange;
  }

  void PreferencesDialog::OnUpClick()
  {
    QList<QTableWidgetSelectionRange> selection = m_pTable->selectedRanges();
    int const selSize = selection.size();
    if (selSize && selection[0].topRow() > 0)
    {
      for (int i = 0; i < selSize; ++i)
      {
        m_pTable->setRangeSelected(selection[i], false);
        for (int j = selection[i].topRow(); j < selection[i].topRow() + selection[i].rowCount(); ++j)
          SwapRows(*m_pTable, j, j - 1);
      }

      ShiftSelectionRange(selection, -1);
      for (int i = 0; i < selSize; ++i)
        m_pTable->setRangeSelected(selection[i], true);
      m_pTable->scrollToItem(m_pTable->item(selection[0].topRow(), 0));
    }
  }

  void PreferencesDialog::OnDownClick()
  {
    QList<QTableWidgetSelectionRange> selection = m_pTable->selectedRanges();
    int const selSize = selection.size();
    if (selSize && selection[selSize - 1].bottomRow() < m_pTable->rowCount() - 1)
    {
      for (int i = selSize - 1; i >= 0; --i)
      {
        m_pTable->setRangeSelected(selection[i], false);
        for (int j = selection[i].bottomRow(); j > selection[i].bottomRow() - selection[i].rowCount(); --j)
          SwapRows(*m_pTable, j, j + 1);
      }
      ShiftSelectionRange(selection, +1);
      for (int i = 0; i < selSize; ++i)
        m_pTable->setRangeSelected(selection[i], true);
      m_pTable->scrollToItem(m_pTable->item(selection[selSize - 1].bottomRow(), 0));
    }
  }

  void PreferencesDialog::done(int code)
  {
    languages::CodesT langCodes;
    for (int i = 0; i < m_pTable->rowCount(); ++i)
      langCodes.push_back(m_pTable->item(i, 0)->text().toUtf8().constData());
    languages::SaveSettings(langCodes);

    QDialog::done(code);
  }
}
